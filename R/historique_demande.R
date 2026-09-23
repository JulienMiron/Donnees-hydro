# Télécharge l'historique horaire de la demande depuis l'API du portail de données
# d'Hydro-Québec (2019 à la dernière année publiée). Les dates y sont en UTC,
# ce qui évite toute ambiguïté liée au changement d'heure.
# Lancé à chaque collecte : une seule requête, et les nouvelles années publiées
# (2025, 2026…) seront intégrées automatiquement.

source("R/utils.R")

URL_API_HISTO <- "https://donnees.hydroquebec.com/api/explore/v2.1/catalog/datasets/historique-demande-electricite-quebec/exports/csv"

tmp <- tempfile(fileext = ".csv")
requete(URL_API_HISTO) |>
  req_url_query(delimiter = ",", timezone = "UTC") |>
  req_perform(path = tmp)

x <- read_csv(tmp, col_types = cols(.default = col_character()), progress = FALSE)
if (!all(c("date", "moyenne_mw") %in% names(x)))
  stop("Colonnes inattendues : ", paste(names(x), collapse = ", "))

hist <- x |>
  transmute(heure_fin_utc = ymd_hms(date, quiet = TRUE),
            demande_mw = moyenne_mw) |>
  filter(!is.na(heure_fin_utc), !is.na(demande_mw)) |>
  mutate(heure_fin_utc = format(heure_fin_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")) |>
  arrange(heure_fin_utc) |>
  distinct(heure_fin_utc, .keep_all = TRUE)

if (nrow(hist) < 40000) stop("Historique anormalement court : ", nrow(hist), " lignes")

dir.create(dirname(CHEMIN_DEMANDE_HIST), recursive = TRUE, showWarnings = FALSE)
write_csv(hist, CHEMIN_DEMANDE_HIST, na = "")   # remplace le fichier : l'API fait foi
message(sprintf("Historique : %d heures, de %s à %s",
                nrow(hist), min(hist$heure_fin_utc), max(hist$heure_fin_utc)))
