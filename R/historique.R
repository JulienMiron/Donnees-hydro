# À lancer une seule fois : télécharge l'historique horaire de la demande
# et les températures depuis 2019.

source("R/utils.R")

# 1. Demande historique ---------------------------------------------------------
source("R/historique_demande.R")

# 2. Température depuis 2019 ------------------------------------------------------
stations <- lire_stations()
mois <- seq(make_date(2019, 1, 1), floor_date(today(), "month"), by = "month")

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
