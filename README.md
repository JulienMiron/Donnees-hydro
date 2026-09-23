# Demande d'électricité au Québec et température

Jeu de données horaire jumelant la demande totale d'électricité au Québec
(Hydro-Québec) et la température observée (Environnement et Changement
climatique Canada), à des fins d'analyse statistique.

## Fichier principal

`data/demande_temperature_horaire.csv`, une ligne par heure :

| Variable | Description |
|---|---|
| `heure_fin_utc` | Fin de l'heure, en UTC (ISO 8601) |
| `date_locale`, `annee`, `mois` | Date locale du début de l'heure |
| `jour_semaine` | 1 = lundi, …, 7 = dimanche |
| `heure_locale` | Heure locale de début (0 = de 0 h à 1 h) |
| `est_ferie`, `ferie` | Jour férié au Québec (date calendaire, sans report) |
| `demande_mw` | Demande totale moyenne pendant l'heure, en MW |
| `source_demande` | `historique` (fichiers annuels) ou `temps_reel` (agrégé des valeurs aux 15 minutes) |
| `n_obs_15min` | Nombre de valeurs aux 15 minutes dans l'heure (4 si complète) |
| `temp_ponderee` | Moyenne des températures des stations, pondérée par la population (°C) |
| `n_stations` | Nombre de stations disponibles pour cette heure |
| `temp_<ville>` | Température observée à chaque station (°C) |

La demande de l'heure se terminant à *t* est jumelée à la température observée à *t*.

## Sources

- Demande historique (2019–2023) : [Historique de la demande d'électricité au Québec](https://www.hydroquebec.com/documents-donnees/donnees-ouvertes/historique-demande-electricite-quebec/)
- Demande récente (pas de 15 min, fenêtre d'environ deux jours, captée toutes les 6 heures) : [Demande d'électricité au Québec](https://www.hydroquebec.com/documents-donnees/donnees-ouvertes/demande-electricite-quebec/)
- Température : API GeoMet-OGC d'ECCC, collection `climate-hourly`

## Licences

- Données d'Hydro-Québec : [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/legalcode.fr), source : Hydro-Québec. Usage commercial interdit.
- Données d'ECCC : Licence du gouvernement ouvert – Canada.

## Structure

```
R/utils.R             paramètres et fonctions communes
R/trouver_stations.R  (une fois) choisit les stations météo
R/historique.R        (une fois) télécharge l'historique 2019–2023 et la météo depuis 2019
R/collecte_demande.R  (automatique) capte le JSON de la demande
R/collecte_meteo.R    (automatique) capte la météo des deux derniers mois
R/construire.R        (automatique) produit le fichier final
config/stations.csv   stations, codes et poids (population des RMR, approximative)
data/brut/            données brutes telles que publiées
```

## Mise en route

```
Rscript R/trouver_stations.R   # vérifier les stations retenues dans config/stations.csv
Rscript R/historique.R
Rscript R/construire.R
```

## Limites connues

- **Trou 2024 – septembre 2026** : l'historique publié s'arrête à 2023. À combler avec les
  historiques officiels de production et de consommation, ou les prochains fichiers annuels.
- **Fuseau horaire d'Hydro-Québec non documenté** : l'hypothèse est l'heure locale avec
  changement d'heure (`TZ_HQ` dans `R/utils.R`), à confirmer au changement d'heure.
- Les données temps réel d'Hydro-Québec sont brutes et non officielles.
- La température est ponctuelle (observation à l'heure pile), alors que la demande est une moyenne horaire.
