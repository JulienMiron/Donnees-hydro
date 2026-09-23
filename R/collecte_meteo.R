# Récupère les températures horaires ECCC du mois courant et du mois précédent
# pour chaque station de config/stations.csv (les archives ont un léger délai,
# d'où le recouvrement), puis les ajoute à data/brut/meteo_horaire.csv.

source("R/utils.R")

stations <- lire_stations()
aujourdhui <- today(tzone = "UTC")
mois_cibles <- c(floor_date(aujourdhui, "month") - months(1), floor_date(aujourdhui, "month"))

obs <- map_dfr(stations$climate_id, function(id) {
  map_dfr(mois_cibles, function(m) {
    Sys.sleep(0.5)
    tryCatch(meteo_mois(id, year(m), month(m)),
             error = function(e) {
               warning(sprintf("Station %s, %s : %s", id, m, conditionMessage(e)))
               tibble()
             })
  })
})

if (nrow(obs) == 0) stop("Aucune observation météo récupérée")

obs <- mutate(obs, collecte_utc = horodatage_utc())
tout <- ajouter_dedoublonner(obs, CHEMIN_METEO, c("CLIMATE_IDENTIFIER", "UTC_DATE"))
message(sprintf("%d observations captées ; %d lignes au total", nrow(obs), nrow(tout)))
