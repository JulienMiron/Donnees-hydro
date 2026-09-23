# À lancer une seule fois (puis de nouveau si une station ferme).
# Pour chaque ville de config/stations.csv sans climate_id, cherche parmi les
# stations québécoises à données horaires celle dont le nom correspond au motif
# et dont les données horaires sont les plus récentes. Vérifier le résultat !

source("R/utils.R")

lister <- function(...) {
  js <- requete(paste0(URL_ECCC, "/climate-stations/items")) |>
    req_url_query(PROV_STATE_TERR_CODE = "QC", limit = 10000, f = "json", ...) |>
    req_perform() |>
    resp_body_json(simplifyVector = TRUE)
  as_tibble(js$features$properties)
}

toutes <- lister(HAS_HOURLY_DATA = "Y")
if (nrow(toutes) == 0) toutes <- lister()
toutes <- toutes |>
  filter(!is.na(HLY_LAST_DATE)) |>
  select(STATION_NAME, CLIMATE_IDENTIFIER, HLY_FIRST_DATE, HLY_LAST_DATE)

config <- read_csv(CHEMIN_STATIONS, col_types = cols(.default = col_character()),
                   comment = "#", progress = FALSE)

for (i in seq_len(nrow(config))) {
  cand <- toutes |>
    filter(grepl(config$motif_nom[i], STATION_NAME, ignore.case = TRUE)) |>
    arrange(desc(HLY_LAST_DATE), HLY_FIRST_DATE)
  cat("\n==", config$ville[i], "==\n")
  print(head(cand, 5))
  if (is.na(config$climate_id[i]) || config$climate_id[i] == "") {
    if (nrow(cand) == 0) { warning("Aucune station pour ", config$ville[i]); next }
    config$climate_id[i]  <- cand$CLIMATE_IDENTIFIER[1]
    config$nom_station[i] <- cand$STATION_NAME[1]
    if (substr(cand$HLY_FIRST_DATE[1], 1, 4) > "2018")
      warning(config$ville[i], " : la station retenue ne couvre pas 2019 en entier")
  }
}

write_csv(config, CHEMIN_STATIONS, na = "")
message("\nconfig/stations.csv mis à jour ; vérifier les choix avant de committer.")
