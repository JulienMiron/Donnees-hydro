# Fonctions et paramètres communs ---------------------------------------------

suppressPackageStartupMessages({
  library(httr2)
  library(dplyr)
  library(readr)
  library(lubridate)
  library(purrr)
  library(tidyr)
})

# Fuseau horaire des horodatages d'Hydro-Québec.
# HYPOTHÈSE à valider au changement d'heure du 1er novembre 2026 :
#   "America/Toronto" = heure locale de l'Est AVEC changement d'heure
#   "Etc/GMT+5"       = heure normale de l'Est fixe (UTC-5 toute l'année)
# Confirmé en septembre 2026 : heure locale avec changement d'heure.
TZ_HQ <- "America/Toronto"

TZ_LOCAL <- "America/Toronto"  # pour les variables calendaires

URL_DEMANDE <- "https://www.hydroquebec.com/data/documents-donnees/donnees-ouvertes/json/demande.json"
URL_ECCC    <- "https://api.weather.gc.ca/collections"

CHEMIN_DEMANDE_15   <- "data/brut/demande_15min.csv"
CHEMIN_DEMANDE_HIST <- "data/brut/demande_historique_horaire.csv"
CHEMIN_METEO        <- "data/brut/meteo_horaire.csv"
CHEMIN_STATIONS     <- "config/stations.csv"
CHEMIN_FINAL        <- "data/demande_temperature_horaire.csv"

`%||%` <- function(x, y) if (is.null(x)) y else x

horodatage_utc <- function() format(now(tzone = "UTC"), "%Y-%m-%dT%H:%M:%SZ")

requete <- function(url) {
  request(url) |>
    req_user_agent("Donnees-Hydro (collecte de donnees ouvertes a des fins statistiques)") |>
    req_retry(max_tries = 4, backoff = ~ 15) |>
    req_timeout(120)
}

# Ajoute des lignes à un CSV brut et dédoublonne sur `cles`, en gardant la
# version la plus récemment collectée (les valeurs récentes peuvent être révisées).
# Tout est stocké en texte : la couche brute reproduit la source telle quelle.
ajouter_dedoublonner <- function(nouveau, chemin, cles) {
  nouveau <- mutate(nouveau, across(everything(), as.character))
  if (file.exists(chemin)) {
    ancien <- read_csv(chemin, col_types = cols(.default = col_character()),
                       na = "", progress = FALSE)
    nouveau <- bind_rows(ancien, nouveau)
  }
  resultat <- nouveau |>
    arrange(across(all_of(cles)), collecte_utc) |>
    group_by(across(all_of(cles))) |>
    slice_tail(n = 1) |>
    ungroup()
  dir.create(dirname(chemin), recursive = TRUE, showWarnings = FALSE)
  write_csv(resultat, chemin, na = "")
  invisible(resultat)
}

lire_stations <- function() {
  st <- read_csv(CHEMIN_STATIONS, col_types = cols(.default = col_character()),
                 comment = "#", progress = FALSE) |>
    mutate(poids = as.numeric(poids))
  if (any(is.na(st$climate_id) | st$climate_id == "")) {
    stop("Des stations n'ont pas de climate_id. Lancer d'abord : Rscript R/trouver_stations.R")
  }
  st
}

# Observations horaires ECCC d'une station pour un mois (au plus 744 lignes).
# LOCAL_DATE est en heure normale locale (sans changement d'heure) ; on se fie à UTC_DATE.
meteo_mois <- function(climate_id, annee, mois) {
  js <- requete(paste0(URL_ECCC, "/climate-hourly/items")) |>
    req_url_query(CLIMATE_IDENTIFIER = climate_id,
                  LOCAL_YEAR = annee, LOCAL_MONTH = mois,
                  limit = 1000, f = "json") |>
    req_perform() |>
    resp_body_json(simplifyVector = TRUE)
  if (is.null(js$features) || NROW(js$features) == 0) return(tibble())
  as_tibble(js$features$properties) |>
    select(any_of(c("CLIMATE_IDENTIFIER", "STATION_NAME", "UTC_DATE", "LOCAL_DATE",
                    "TEMP", "HUMIDEX", "WINDCHILL", "RELATIVE_HUMIDITY", "WIND_SPEED")))
}

# Jours fériés au Québec ------------------------------------------------------

paques <- function(annee) {  # algorithme de Meeus/Jones/Butcher (calendrier grégorien)
  a <- annee %% 19; b <- annee %/% 100; c <- annee %% 100
  d <- b %/% 4; e <- b %% 4; f <- (b + 8) %/% 25; g <- (b - f + 1) %/% 3
  h <- (19 * a + b - d - g + 15) %% 30; i <- c %/% 4; k <- c %% 4
  l <- (32 + 2 * e + 2 * i - h - k) %% 7; m <- (a + 11 * h + 22 * l) %/% 451
  n <- h + l - 7 * m + 114
  make_date(annee, n %/% 31, (n %% 31) + 1)
}

nieme_lundi <- function(annee, mois, n) {
  d <- make_date(annee, mois, 1)
  d + ((1 - wday(d, week_start = 1)) %% 7) + 7 * (n - 1)
}

feries_quebec <- function(annees) {
  map_dfr(annees, function(a) {
    p <- paques(a)
    mai24 <- make_date(a, 5, 24)
    tibble(
      date = c(make_date(a, 1, 1), p - 2, p + 1,
               mai24 - ((wday(mai24, week_start = 1) - 1) %% 7),
               make_date(a, 6, 24), make_date(a, 7, 1),
               nieme_lundi(a, 9, 1), nieme_lundi(a, 10, 2), make_date(a, 12, 25)),
      ferie = c("Jour de l'An", "Vendredi saint", "Lundi de Pâques",
                "Journée nationale des patriotes", "Fête nationale", "Fête du Canada",
                "Fête du Travail", "Action de grâce", "Noël")
    )
  })
}
