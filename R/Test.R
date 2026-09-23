library(httr2)
base <- "https://donnees.hydroquebec.com/api/explore/v2.1/catalog/datasets/"

sonder <- function(id) {
  tryCatch({
    meta <- request(paste0(base, id)) |> req_perform() |> resp_body_json()
    champs <- vapply(meta$fields, \(f) paste0(f$name, " (", f$type, ")"), "")
    champ_date <- Filter(\(f) f$type %in% c("datetime", "date"), meta$fields)[[1]]$name
    agr <- request(paste0(base, id, "/records")) |>
      req_url_query(select = sprintf("min(%s) as debut, max(%s) as fin, count(*) as n",
                                     champ_date, champ_date)) |>
      req_perform() |> resp_body_json()
    cat("\n==", id, "==\nChamps :", paste(champs, collapse = ", "), "\n")
    str(agr$results[[1]])
  }, error = \(e) cat("\n==", id, "== erreur :", conditionMessage(e), "\n"))
}

for (id in c("historique-demande-electricite-quebec",
             "demande-electricite-quebec",
             "historique-production-consommation-ec-horaire",
             "historique-production-consommation-proxy-horaire")) sonder(id)
