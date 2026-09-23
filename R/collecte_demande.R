# Capte le fichier JSON de la demande (fenêtre d'environ deux jours, pas de 15 min)
# et l'ajoute à data/brut/demande_15min.csv. À lancer plusieurs fois par jour.

source("R/utils.R")

brut <- requete(URL_DEMANDE) |>
  req_perform() |>
  resp_body_json(simplifyVector = FALSE)

obs <- tibble(
  date_hq    = map_chr(brut$details, "date"),
  demande_mw = map_dbl(brut$details, ~ .x$valeurs$demandeTotal %||% NA_real_)
) |>
  # Si Hydro-Québec publie en heure locale, la nuit du retour à l'heure normale
  # contient deux fois les mêmes horodatages : on les distingue par leur rang.
  group_by(date_hq) |>
  mutate(occurrence = row_number()) |>
  ungroup() |>
  filter(!is.na(demande_mw)) |>
  mutate(collecte_utc = horodatage_utc())

if (nrow(obs) == 0) stop("Aucune valeur de demande dans le JSON : format modifié ?")
if (any(obs$occurrence > 1)) message("Horodatages dupliqués détectés (changement d'heure ?)")

tout <- ajouter_dedoublonner(obs, CHEMIN_DEMANDE_15, c("date_hq", "occurrence"))
message(sprintf("%d valeurs captées (%s à %s) ; %d lignes au total",
                nrow(obs), min(obs$date_hq), max(obs$date_hq), nrow(tout)))
