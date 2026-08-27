library(data.table)
library(readxl)
library(ggplot2)
library(dplyr)

# ==========================================================
# Total SVOC chemical burden - real per-household ratios, both
# platforms, feeding a horizontal raincloud plot (replacement for
# the two 8-facet violin grids, panels c/d).
#
# LC-HRMS: deployment (Indoor/Outdoor) comes from the "Class" row
#   (row 1 of the raw CSV), matched by COLUMN POSITION to the
#   sample columns - NOT from the "_1_"/"_2_" suffix in the sample
#   name, which is not a reliable indoor/outdoor flag (confirmed
#   against the 10-row format example and the original LC script's
#   own parse_sample_v2() logic).
#   Country and house number ARE reliably read from the sample
#   name itself: Sample_H{house}_{1|2}_ESIPOS_{injection}_{COUNTRY}
#
# GC-HRMS: deployment comes directly from the sample name suffix
#   (_IS1 = indoor, _OS1 = outdoor), country from the name prefix,
#   with the known SI/SL naming fix applied.
# ==========================================================

# ---------- Paths (edit these) ----------
data_dir <- "path/to/data"
lc_path <- file.path(data_dir, "Full_dataset_INQUIRE_nontarget_FINAL_only_samples.csv")
gc_path <- file.path(data_dir, "20260818_INQUIRE_sVOC_FINAL_FL_newNormalization_03_coding correct.xlsx")
out_dir <- data_dir
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# ==========================================================
# STEP 1: LC-HRMS - real per-household total burden ratios
# ==========================================================
cat("Reading LC header rows...\n")
lc_header_lines <- readLines(lc_path, n = 4)
class_row  <- strsplit(lc_header_lines[1], ",")[[1]]
colname_row <- strsplit(lc_header_lines[4], ",")[[1]]

sample_col_idx <- which(colname_row != "" & startsWith(colname_row, "Sample_"))
cat("LC sample columns found:", length(sample_col_idx), "\n")

sample_names <- colname_row[sample_col_idx]
deploy       <- class_row[sample_col_idx]   # Indoor / Outdoor, position-matched

# Parse house + country from the sample name (these two ARE reliable from the name)
parse_lc_name <- function(s) {
  m_house   <- regmatches(s, regexpr("H\\d+", s))
  m_country <- regmatches(s, regexpr("[A-Z]{2}$", s))
  house   <- if (length(m_house) > 0) m_house else NA
  country <- if (length(m_country) > 0) m_country else NA
  c(house, country)
}
lc_meta <- as.data.frame(t(sapply(sample_names, parse_lc_name)), stringsAsFactors = FALSE)
colnames(lc_meta) <- c("House", "Country")
lc_meta$SampleName <- sample_names
lc_meta$Deploy     <- deploy
lc_meta$ColIndex   <- sample_col_idx

cat("Reading LC data (fread, sample columns only)...\n")
# Fast-read only the needed sample columns, skipping the 4 metadata rows
lc_dt <- fread(lc_path, skip = 4, header = FALSE,
               select = sample_col_idx, colClasses = "numeric")
setnames(lc_dt, as.character(sample_col_idx))

cat("LC feature rows loaded:", nrow(lc_dt), "\n")

# Total burden per sample = column sum across all features
lc_burden <- colSums(lc_dt, na.rm = TRUE)
lc_meta$Burden <- lc_burden[as.character(lc_meta$ColIndex)]

# Pair Indoor/Outdoor by House + Country, compute log ratio
lc_pairs <- lc_meta %>%
  group_by(House, Country) %>%
  summarise(
    Indoor  = Burden[Deploy == "Indoor"][1],
    Outdoor = Burden[Deploy == "Outdoor"][1],
    .groups = "drop"
  ) %>%
  filter(!is.na(Indoor), !is.na(Outdoor), Indoor > 0, Outdoor > 0) %>%
  mutate(LogRatio = log(Indoor / Outdoor), Platform = "LC-HRMS")

cat("LC valid pairs:", nrow(lc_pairs), "\n\n")

# ==========================================================
# STEP 2: GC-HRMS - real per-household total burden ratios
# ==========================================================
cat("Reading GC file...\n")
gc_raw <- read_excel(gc_path, sheet = "FL_normalized", col_names = TRUE)
gc_raw <- gc_raw[-1, ]  # drop blank spacer row

gc_cols <- colnames(gc_raw)
gc_sample_cols <- gc_cols[grepl("^[A-Za-z]+_HH_0*\\d+_(IS1|OS1)$", gc_cols)]
cat("GC sample columns found:", length(gc_sample_cols), "\n")

parse_gc_name <- function(s) {
  m <- regmatches(s, regexec("^([A-Za-z]+)_HH_0*(\\d+)_(IS1|OS1)$", s))[[1]]
  country <- m[2]; if (country == "SI") country <- "SL"
  c(house = m[3], country = country, type = m[4])
}
gc_meta <- as.data.frame(t(sapply(gc_sample_cols, parse_gc_name)), stringsAsFactors = FALSE)
colnames(gc_meta) <- c("House", "Country", "Type")
gc_meta$SampleName <- gc_sample_cols

gc_num <- as.data.frame(lapply(gc_raw[, gc_sample_cols], function(x) suppressWarnings(as.numeric(x))))
gc_burden <- colSums(gc_num, na.rm = TRUE)
gc_meta$Burden <- gc_burden[gc_meta$SampleName]

gc_pairs <- gc_meta %>%
  group_by(House, Country) %>%
  summarise(
    Indoor  = Burden[Type == "IS1"][1],
    Outdoor = Burden[Type == "OS1"][1],
    .groups = "drop"
  ) %>%
  filter(!is.na(Indoor), !is.na(Outdoor), Indoor > 0, Outdoor > 0) %>%
  mutate(LogRatio = log(Indoor / Outdoor), Platform = "GC-HRMS")

cat("GC valid pairs:", nrow(gc_pairs), "\n\n")

# ==========================================================
# STEP 3: Combine and plot (real data, horizontal raincloud)
# ==========================================================
combined <- bind_rows(
  lc_pairs %>% select(Country, Platform, LogRatio),
  gc_pairs %>% select(Country, Platform, LogRatio)
)

country_order <- c("EE","PT","UK","CZ","SI","SE","IT","NL")
combined$Country[combined$Country == "SL"] <- "SI"  # unify display label (GC's SL was only for internal matching)
combined$Country <- factor(combined$Country, levels = rev(country_order))

col_lc <- "#5A2D75"  # dark purple - platform color, distinct from Indoor/Outdoor red/blue elsewhere
col_gc <- "#A85A1F"  # dark orange

combined$y_num <- as.numeric(combined$Country)
combined$y_off <- ifelse(combined$Platform == "LC-HRMS", combined$y_num + 0.22, combined$y_num - 0.22)

build_density_polygon <- function(vals, baseline, scale = 1, half = FALSE, side = 1) {
  d <- density(vals, n = 512)
  h <- d$y / max(d$y) * scale
  if (half) {
    data.frame(x = c(d$x, rev(d$x)), y = c(baseline + h * side, rep(baseline, length(d$x))))
  } else {
    data.frame(x = d$x, y = baseline + h)
  }
}

half_polys <- do.call(rbind, lapply(unique(paste(combined$Country, combined$Platform)), function(g) {
  sub <- combined[paste(combined$Country, combined$Platform) == g, ]
  if (nrow(sub) < 2) return(NULL)
  poly <- build_density_polygon(sub$LogRatio, baseline = sub$y_off[1], scale = 0.16, half = TRUE, side = 1)
  poly$Country <- sub$Country[1]; poly$Platform <- sub$Platform[1]
  poly
}))

box_stats <- combined %>% group_by(Country, Platform, y_off) %>%
  summarise(ymin = quantile(LogRatio, 0.25) - 1.5*IQR(LogRatio),
            lower = quantile(LogRatio, 0.25), med = median(LogRatio),
            upper = quantile(LogRatio, 0.75),
            ymax = quantile(LogRatio, 0.75) + 1.5*IQR(LogRatio), .groups = "drop")

p_raincloud <- ggplot() +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  geom_polygon(data = half_polys, aes(x = x, y = y, group = interaction(Country, Platform), fill = Platform, color = Platform),
               alpha = 0.55, linewidth = 0.5) +
  geom_boxplot(data = box_stats, aes(xmin = ymin, xlower = lower, xmiddle = med, xupper = upper, xmax = ymax,
                                       y = y_off - 0.05, group = interaction(Country, Platform), fill = Platform),
               stat = "identity", width = 0.06, alpha = 0.9, orientation = "y",
               color = "grey15", linewidth = 0.9) +
  geom_jitter(data = combined, aes(x = LogRatio, y = y_off - 0.11, color = Platform),
              width = 0, height = 0.03, size = 1.6, alpha = 0.6) +
  scale_y_continuous(breaks = seq_along(levels(combined$Country)), labels = levels(combined$Country)) +
  scale_fill_manual(values = c("LC-HRMS" = col_lc, "GC-HRMS" = col_gc)) +
  scale_color_manual(values = c("LC-HRMS" = col_lc, "GC-HRMS" = col_gc)) +
  labs(title = "Total SVOC Chemical Burden - Indoor/Outdoor Ratio by Country",
       subtitle = "Real data, both platforms",
       x = "log(Indoor/Outdoor total burden ratio)", y = NULL) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank(), legend.position = "top")

print(p_raincloud)
ggsave(file.path(out_dir, "Fig_Raincloud_LC_GC_ByCountry.png"), p_raincloud, dpi = 600, width = 8, height = 12)
write.csv(combined, file.path(out_dir, "Combined_LC_GC_ByCountry_Ratios.csv"), row.names = FALSE)
cat("Saved outputs to:", out_dir, "\n")
