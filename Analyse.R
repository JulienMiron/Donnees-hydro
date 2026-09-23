library(readr); library(dplyr)
url <- "https://raw.githubusercontent.com/JulienMiron/Donnees-hydro/main/data/demande_temperature_horaire.csv"
d <- read_csv(url) |>
  filter(!is.na(demande_mw), !is.na(temp_ponderee)) |>
  mutate(T = temp_ponderee, h = factor(heure_locale),
         jt = factor(ifelse(est_ferie | jour_semaine >= 6, "congé", "ouvrable")))

seuils <- 8:22
r2 <- sapply(seuils, \(b) summary(lm(demande_mw ~ pmax(b - T, 0) + pmax(T - b, 0) + h * jt, d))$r.squared)
b <- seuils[which.max(r2)]
modele <- lm(demande_mw ~ pmax(b - T, 0) + pmax(T - b, 0) + h * jt, d)
coef(modele)[2:3]   # MW par °C sous et au-dessus du seuil