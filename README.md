# Demande d'électricité au Québec et température

Jeu de données horaire jumelant la **demande totale d'électricité au Québec** (Hydro-Québec)
et la **température observée** dans six villes (Environnement et Changement climatique
Canada, ECCC), conçu pour l'analyse statistique : régression, séries chronologiques,
modélisation des pointes hivernales, etc.

Le dépôt se met à jour automatiquement toutes les 6 heures (GitHub Actions).

## En bref

| | |
|---|---|
| Fichier principal | `data/demande_temperature_horaire.csv` |
| Unité d'observation | une heure |
| Période | du 1er janvier 2019 à la dernière heure captée |
| Demande disponible | 2019–2024 (historique), puis depuis le 20 septembre 2026 (temps réel) |
| Température disponible | toute la période |
| Mise à jour | toutes les 6 heures |

Lecture directe dans R, toujours dans sa version la plus récente :

```r
library(readr); library(dplyr)
url <- "https://raw.githubusercontent.com/JulienMiron/Donnees-hydro/main/data/demande_temperature_horaire.csv"
d <- read_csv(url) |>
  filter(!is.na(demande_mw), !is.na(temp_ponderee),
         is.na(n_obs_15min) | n_obs_15min == 4)   # heures complètes seulement
```

## Le fichier principal : `data/demande_temperature_horaire.csv`

Une ligne par heure, sans trou : toutes les heures de la période sont présentes, même
celles où la demande ou la température manque (valeur vide, lue comme `NA`).

### Conventions à connaître

- **Chaque ligne décrit une heure qui se termine à `heure_fin_utc`.** La ligne
  `2024-01-15T13:00:00Z` couvre la période de 12 h à 13 h UTC, soit de 7 h à 8 h à
  l'heure de l'Est en hiver. C'est la convention d'Hydro-Québec.
- **Le temps de référence est l'UTC**, ce qui évite les heures doublées ou manquantes au
  changement d'heure. Les variables calendaires (`date_locale`, `heure_locale`, etc.) sont
  en heure du Québec, changement d'heure compris, et se rapportent au **début** de l'heure.
- **La demande est une moyenne sur l'heure, la température une observation ponctuelle.**
  La demande de l'heure qui se termine à *t* est jumelée à la température mesurée à *t*.

### Variables de temps et de calendrier

| Variable | Type | Description | Exemple |
|---|---|---|---|
| `heure_fin_utc` | date-heure (UTC) | Fin de l'heure décrite par la ligne. Clé unique du fichier. | `2024-01-15T13:00:00Z` |
| `date_locale` | date | Date au Québec au début de l'heure. | `2024-01-15` |
| `annee` | entier | Année de `date_locale`. | `2024` |
| `mois` | entier, 1 à 12 | Mois de `date_locale`. | `1` |
| `jour_semaine` | entier, 1 à 7 | Jour de la semaine : 1 = lundi, …, 6 = samedi, 7 = dimanche. | `1` |
| `heure_locale` | entier, 0 à 23 | Heure locale de début : 0 = de minuit à 1 h, 17 = de 17 h à 18 h. Le jour du retour à l'heure normale, la valeur 1 apparaît deux fois ; le jour du passage à l'heure avancée, la valeur 2 n'existe pas. | `7` |
| `est_ferie` | logique | `TRUE` si `date_locale` est un jour férié au Québec. | `FALSE` |
| `ferie` | texte | Nom du jour férié, vide sinon. Jours retenus : Jour de l'An, Vendredi saint, Lundi de Pâques, Journée nationale des patriotes, Fête nationale, Fête du Canada, Fête du Travail, Action de grâce, Noël. Date calendaire, sans report lorsque le congé tombe un dimanche. | `Noël` |

### Variables de demande

| Variable | Type | Description |
|---|---|---|
| `demande_mw` | réel, MW | Demande totale moyenne d'électricité au Québec pendant l'heure, en mégawatts. Couvre le réseau intégré (tout le Québec sauf les régions alimentées par des réseaux autonomes). Ordre de grandeur : 15 000 MW par une nuit douce d'automne, plus de 40 000 MW lors des grands froids. Vide si la valeur n'est pas disponible. |
| `source_demande` | texte | Provenance de la valeur : `historique` (données horaires publiées par Hydro-Québec) ou `temps_reel` (moyenne des valeurs aux 15 minutes captées par ce dépôt). Vide si `demande_mw` est vide. |
| `n_obs_15min` | entier, 1 à 4 | Pour les données temps réel seulement : nombre de valeurs aux 15 minutes ayant servi à la moyenne. **4 = heure complète.** Une valeur inférieure signale une heure incomplète (typiquement la dernière heure captée, qui se complète à la collecte suivante). Vide pour l'historique. |

### Variables de température

| Variable | Type | Description |
|---|---|---|
| `temp_ponderee` | réel, °C | Température « du Québec habité » : moyenne des températures des stations, **pondérée par la population** de la région que chacune représente (voir plus bas). C'est la variable à privilégier pour expliquer la demande provinciale. |
| `n_stations` | entier, 0 à 6 | Nombre de stations disponibles pour calculer `temp_ponderee`. Quand une station manque, la moyenne est faite sur les autres et leurs poids sont ramenés à 100 %. |
| `temp_montreal` | réel, °C | Température observée à Montréal (aéroport Montréal-Trudeau). |
| `temp_quebec` | réel, °C | Température observée à Québec. |
| `temp_gatineau` | réel, °C | Température observée à Gatineau. |
| `temp_sherbrooke` | réel, °C | Température observée à Sherbrooke. |
| `temp_trois_rivieres` | réel, °C | Température observée à Trois-Rivières. |
| `temp_saguenay` | réel, °C | Température observée à Saguenay (Bagotville). |

Les stations exactes (nom et identifiant climatologique ECCC) sont dans `config/stations.csv`.

#### Comment se calcule `temp_ponderee`

Pour chaque heure :

$$T_{\text{pondérée}} = \frac{\sum_i p_i \, T_i}{\sum_i p_i}$$

où $T_i$ est la température à la station $i$ et $p_i$ la population de la région
métropolitaine qu'elle représente (recensement 2021, valeurs arrondies), la somme portant
sur les stations disponibles.

| Station | Population (poids) | Part |
|---|---|---|
| Montréal | 4 291 732 | 71 % |
| Québec | 839 311 | 14 % |
| Gatineau (partie québécoise) | 340 000 | 6 % |
| Sherbrooke | 227 398 | 4 % |
| Trois-Rivières | 161 489 | 3 % |
| Saguenay | 160 980 | 3 % |

Exemple : −10 °C à Montréal, −15 °C à Québec, −12 °C à Gatineau, −13 °C à Sherbrooke,
−14 °C à Trois-Rivières et −20 °C à Saguenay donnent une moyenne simple de −14,0 °C, mais
une température pondérée d'environ **−11,3 °C**, proche de Montréal où vit la majorité
de la population.

Montréal pèse 71 % : une heure où `temp_montreal` manque donne une `temp_ponderee` de
nature différente. Pour une analyse rigoureuse, on peut exclure ces heures.

### Données manquantes

| Situation | Effet dans le fichier |
|---|---|
| Janvier 2025 à septembre 2026 | `demande_mw` vide : l'année 2025 n'est pas encore publiée par Hydro-Québec. Se comblera automatiquement à sa publication. |
| Quelques heures de l'historique (dont les 21 et 23 juin et le 11 novembre 2019) | `demande_mw` vide : absentes de la source. |
| Dernières heures du fichier | Température souvent vide : ECCC publie ses observations avec quelques heures de retard. Se complète aux collectes suivantes. |
| Station en panne ou en maintenance | Colonne `temp_<ville>` vide, `n_stations` réduit. |

## Les fichiers bruts : `data/brut/`

Matière première, conservée telle que publiée par les sources. Pour l'analyse, utiliser
le fichier principal.

**`demande_historique_horaire.csv`**, demande horaire historique, relue à chaque collecte
depuis l'API du portail de données d'Hydro-Québec :

| Variable | Description |
|---|---|
| `heure_fin_utc` | Fin de l'heure, en UTC. |
| `demande_mw` | Demande moyenne pendant l'heure (MW). |

**`demande_15min.csv`**, demande aux 15 minutes, accumulée par ce dépôt à partir du flux
temps réel d'Hydro-Québec (qui ne conserve qu'environ deux jours) :

| Variable | Description |
|---|---|
| `date_hq` | Horodatage tel que publié par Hydro-Québec, en heure locale du Québec (changement d'heure compris), fin du pas de 15 minutes. |
| `occurrence` | 1 en général ; 2 pour la seconde occurrence d'un horodatage répété la nuit du retour à l'heure normale. |
| `demande_mw` | Demande totale (MW). |
| `collecte_utc` | Moment où la valeur a été captée. Si une valeur est captée plusieurs fois, la plus récente est conservée. |

**`meteo_horaire.csv`**, observations horaires d'ECCC (collection `climate-hourly`) :

| Variable | Description |
|---|---|
| `CLIMATE_IDENTIFIER` | Identifiant climatologique de la station. |
| `STATION_NAME` | Nom de la station. |
| `UTC_DATE` | Moment de l'observation, en UTC. |
| `LOCAL_DATE` | Moment de l'observation en heure normale locale (sans changement d'heure). |
| `TEMP` | Température de l'air (°C). |
| `HUMIDEX`, `WINDCHILL` | Indice humidex et refroidissement éolien, quand ils s'appliquent. |
| `RELATIVE_HUMIDITY` | Humidité relative (%). |
| `WIND_SPEED` | Vitesse du vent (km/h). |
| `collecte_utc` | Moment de la capture. |

Les variables d'humidité et de vent ne sont pas reportées dans le fichier principal, mais
sont disponibles ici pour qui veut les ajouter.

## Sources

- **Demande historique** : Hydro-Québec, jeu [Historique de la demande d'électricité au Québec](https://donnees.hydroquebec.com/explore/dataset/historique-demande-electricite-quebec/), par l'API du portail de données.
- **Demande temps réel** : Hydro-Québec, jeu [Demande d'électricité au Québec](https://www.hydroquebec.com/documents-donnees/donnees-ouvertes/demande-electricite-quebec/) (flux JSON mis à jour aux 15 minutes).
- **Température** : Environnement et Changement climatique Canada, API GeoMet-OGC, collection `climate-hourly`.

Les données d'Hydro-Québec sont calculées en temps réel par son Centre de conduite du
réseau. Elles sont offertes à titre informatif et ne constituent pas les données
officielles transmises à la Régie de l'énergie.

## Licences

- Données d'Hydro-Québec : [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/legalcode.fr). Source : Hydro-Québec. Usage commercial interdit.
- Données d'ECCC : Licence du gouvernement ouvert – Canada.

## Structure du dépôt

```
R/utils.R              paramètres et fonctions communes
R/trouver_stations.R   (une fois) choisit les stations météo
R/historique.R         (une fois) télécharge l'historique de la demande et la météo depuis 2019
R/historique_demande.R (automatique) relit l'historique de la demande par l'API
R/collecte_demande.R   (automatique) capte le flux temps réel de la demande
R/collecte_meteo.R     (automatique) capte la météo des deux derniers mois
R/construire.R         (automatique) produit le fichier principal
config/stations.csv    stations, codes et poids
data/brut/             données brutes
```

Pour tout reconstruire en local :

```
Rscript R/trouver_stations.R   # puis vérifier config/stations.csv
Rscript R/historique.R
Rscript R/construire.R