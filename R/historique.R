# À lancer une seule fois : télécharge l'historique horaire publié par
# Hydro-Québec (fichiers Excel annuels) et les températures depuis 2019.

source("R/utils.R")
library(readxl)

# 1. Demande historique ---------------------------------------------------------
annees <- 2019:2023   # ajouter les années suivantes quand elles seront publiées

lire_annee <- function(a) {
  tmp <- tempfile(fileext = ".xlsx")
  requete(sprintf(URL_HISTO, a)) |> req_perform(path = tmp)
  x <- read_excel(tmp, sheet = 1)
  col_date <- names(x)[map_lgl(x, ~ inherits(.x, "POSIXct"))][1]
  col_val  <- setdiff(names(x)[map_lgl(x, is.numeric)], col_date)[1]
  if (is.na(col_date) || is.na(col_val))
    stop("Colonnes introuvables pour ", a, " : ", paste(names(x), collapse = ", "))
  message(sprintf("%d : colonnes « %s » et « %s », %d lignes", a, col_date, col_val, nrow(x)))
  tibble(
    # readxl lit l'heure affichée dans Excel en l'étiquetant UTC : on la garde telle quelle
    date_hq    = format(x[[col_date]], "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
    demande_mw = x[[col_val]]
  ) |>
    filter(!is.na(date_hq), !is.na(demande_mw)) |>
    group_by(date_hq) |>
    mutate(occurrence = row_number()) |>
    ungroup()
}

hist <- map_dfr(annees, lire_annee) |> mutate(collecte_utc = horodatage_utc())
ajouter_dedoublonner(hist, CHEMIN_DEMANDE_HIST, c("date_hq", "occurrence"))

# 2. Température depuis 2019 ------------------------------------------------------
stations <- lire_stations()
mois <- seq(make_date(min(annees), 1, 1), floor_date(today(), "month"), by = "month")

for (id in stations$climate_id) {
  message("Station ", id)
  obs <- map_dfr(mois, function(m) {
    Sys.sleep(0.3)
    tryCatch(meteo_mois(id, year(m), month(m)),
             error = function(e) {
               warning(sprintf("%s %s : %s", id, m, conditionMessage(e)))
               tibble()
             })
  })
  if (nrow(obs) > 0)
    ajouter_dedoublonner(mutate(obs, collecte_utc = horodatage_utc()),
                         CHEMIN_METEO, c("CLIMATE_IDENTIFIER", "UTC_DATE"))
}
