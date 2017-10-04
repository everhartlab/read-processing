#!/usr/bin/env R

library("purrr")
library("readr")
library("ggplot2")
library("dplyr")
commoncols <- 
cols(
  n = col_integer(),
  `n:500` = col_integer(),
  L50 = col_integer(),
  LG50 = col_integer(),
  NG50 = col_integer(),
  min = col_integer(),
  N80 = col_integer(),
  N50 = col_integer(),
  N20 = col_integer(),
  `E-size` = col_integer(),
  max = col_integer(),
  sum = col_double(),
  name = col_character()
)
stats <- map(dir("ABYSS", full.names = TRUE), dir, pattern = "stats.csv", full.names = TRUE) %>% 
  unlist(use.names = FALSE) %>% 
  setNames(., .) %>% 
  map_df(read_csv, col_types = commoncols, .id = "file") %>%
  write_csv("ABYSS/stats.csv")

meta <- read_csv("/home/everhartlab/shared/processed_data/metadata-BGI.csv", col_types = cols(
  Abbreviation = col_integer(),
  `Sample Code` = col_character(),
  `Sample Name` = col_character(),
  ID = col_integer(),
  Treatment = col_character(),
  Experiment = col_character(),
  Origin = col_character(),
  Year = col_integer(),
  Aggressiveness = col_double(),
  MCG = col_integer(),
  Host = col_character()
)) %>%
  mutate(Treatment = forcats::fct_relevel(Treatment, c("Control", LETTERS[1:4])))


stats %>% 
  tidyr::separate(file, into = c("dir", "K", "file"), sep = "/", remove = TRUE) %>%
  select(-dir, -file) %>%
  filter(grepl("scaffold", name)) %>%
  mutate(name = gsub("-scaffolds.fa", "", name)) %>%
  inner_join(meta, by = c("name" = "Sample Code")) %>%
  ggplot(aes(x = K, y = NG50, group = name)) +
    geom_point(alpha = 0.5) +
    geom_line(aes(color = Treatment, linetype = Experiment)) +
    facet_grid(Treatment~ID) +
    # scale_y_log10() +
    scale_color_brewer(palette = "Dark2")

