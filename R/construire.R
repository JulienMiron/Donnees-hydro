# Construit data/demande_temperature_horaire.csv à partir des fichiers bruts :
# demande horaire (historique + temps réel agrégé), températures par station,
# température pondérée par la population et variables calendaires.

source("R/utils.R")

# Convertit les horodatages d'Hydro-Québec en UTC. Pour une heure ambiguë
# (retour à l'heure normale), la 1re occurrence est l'heure avancée, la 2e l'heure normale.
vers_utc <- function(date_hq, occurrence) {
  naif <- ymd_hms(date_hq, tz = "UTC", quiet = TRUE)
  avant <- force_tz(naif, TZ_HQ, roll_dst = c("NA", "pre"))
  apres <- force_tz(naif, TZ_HQ, roll_dst = c("NA", "post"))
  with_tz(if_else(as.integer(occurrence) == 2L, apres, avant), "UTC")
}

lire_brut <- function(chemin) {
  if (!file.exists(chemin)) return(NULL)
  read_csv(chemin, col_types = cols(.default = col_character()), na = "", progress = FALSE)
}

# 1. Demande ------------------------------------------------------------------
brut15 <- lire_brut(CHEMIN_DEMANDE_15)
brut_h <- lire_brut(CHEMIN_DEMANDE_HIST)
if (is.null(brut15) && is.null(brut_h)) stop("Aucune donnée de demande")

demande <- list()

if (!is.null(brut_h)) {
  demande$hist <- brut_h |>
    transmute(heure_fin_utc = ymd_hms(heure_fin_utc, tz = "UTC"),
              demande_mw = as.numeric(demande_mw),
              n_obs_15min = NA_integer_,
              source_demande = "historique")
}

if (!is.null(brut15)) {
  d15 <- brut15 |>
    transmute(t_utc = vers_utc(date_hq, occurrence), demande_mw = as.numeric(demande_mw))
  if (any(is.na(d15$t_utc)))
    warning(sum(is.na(d15$t_utc)), " horodatages inexistants dans TZ_HQ : ",
            "Hydro-Québec utilise peut-être l'heure normale fixe (voir R/utils.R)")
  # Convention d'Hydro-Québec : la valeur de 2:00 est la moyenne de 1:05 à 2:00.
  # Ici : moyenne des valeurs de 1:15, 1:30, 1:45 et 2:00.
  demande$temps_reel <- d15 |>
    filter(!is.na(t_utc)) |>
    mutate(heure_fin_utc = ceiling_date(t_utc, "hour", change_on_boundary = FALSE)) |>
    group_by(heure_fin_utc) |>
    summarise(demande_mw = mean(demande_mw), n_obs_15min = n(), .groups = "drop") |>
    mutate(source_demande = "temps_reel")
}

demande <- bind_rows(demande) |>
  filter(!is.na(heure_fin_utc)) |>
  arrange(heure_fin_utc, source_demande != "historique") |>
  distinct(heure_fin_utc, .keep_all = TRUE)   # l'historique a priorité en cas de chevauchement

# 2. Température --------------------------------------------------------------
stations <- lire_stations()
brut_meteo <- lire_brut(CHEMIN_METEO)

if (!is.null(brut_meteo)) {
  met <- brut_meteo |>
    transmute(climate_id = CLIMATE_IDENTIFIER,
              heure_utc  = floor_date(ymd_hms(UTC_DATE, tz = "UTC", quiet = TRUE), "hour"),
              temp       = as.numeric(TEMP)) |>
    filter(!is.na(heure_utc)) |>
    inner_join(select(stations, climate_id, code, poids), by = "climate_id")

  temp_ponderee <- met |>
    filter(!is.na(temp)) |>
    group_by(heure_utc) |>
    summarise(temp_ponderee = weighted.mean(temp, poids),
              n_stations = n(), .groups = "drop")

  temp_stations <- met |>
    select(heure_utc, code, temp) |>
    distinct(heure_utc, code, .keep_all = TRUE) |>
    pivot_wider(names_from = code, values_from = temp, names_prefix = "temp_")

  temperature <- full_join(temp_ponderee, temp_stations, by = "heure_utc")
} else {
  warning("Aucune donnée météo : colonnes de température absentes")
  temperature <- tibble(heure_utc = as.POSIXct(character(), tz = "UTC"))
}

# 3. Assemblage et variables calendaires --------------------------------------
# La demande de l'heure se terminant à t est jumelée à l'observation de température à t.
grille <- tibble(heure_fin_utc = seq(min(demande$heure_fin_utc), max(demande$heure_fin_utc), by = "hour"))

final <- grille |>
  left_join(demande, by = "heure_fin_utc") |>
  left_join(temperature, by = c("heure_fin_utc" = "heure_utc")) |>
  mutate(debut_local  = with_tz(heure_fin_utc - hours(1), TZ_LOCAL),
         date_locale  = as_date(debut_local),
         annee        = year(debut_local),
         mois         = month(debut_local),
         heure_locale = hour(debut_local),          # 0 = heure de 0:00 à 1:00
         jour_semaine = wday(debut_local, week_start = 1)) |>   # 1 = lundi
  left_join(feries_quebec(unique(year(grille$heure_fin_utc))), by = c("date_locale" = "date")) |>
  mutate(est_ferie = !is.na(ferie),
         heure_fin_utc = format(heure_fin_utc, "%Y-%m-%dT%H:%M:%SZ"),
         across(c(demande_mw, starts_with("temp_")), ~ round(.x, 2))) |>
  select(heure_fin_utc, date_locale, annee, mois, jour_semaine, heure_locale,
         est_ferie, ferie, demande_mw, source_demande, n_obs_15min,
         any_of(c("temp_ponderee", "n_stations", paste0("temp_", stations$code))))

write_csv(final, CHEMIN_FINAL, na = "")
message(sprintf("%s : %d heures, %d avec demande, %d avec température pondérée",
                CHEMIN_FINAL, nrow(final), sum(!is.na(final$demande_mw)),
                sum(!is.na(final[["temp_ponderee"]] %||% NA))))
