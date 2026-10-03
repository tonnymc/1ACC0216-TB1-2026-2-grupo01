# ============================================================
# FUNDAMENTOS DE DATA SCIENCE
# TB1 - HOTEL BOOKING DEMAND
# ANÁLISIS DE CALIDAD DE DATOS
# ============================================================

# ------------------------------------------------------------
# PREPARACIÓN DEL ENTORNO
# ------------------------------------------------------------

# Elimina todos los objetos almacenados previamente en memoria.
# Permite ejecutar el análisis desde un entorno limpio.

rm(list = ls())

# Cierra dispositivos gráficos que hayan quedado abiertos.

graphics.off()

# Limpia visualmente la consola de RStudio.

cat("\014")


# ------------------------------------------------------------
# CARGA DE LIBRERÍAS
# ------------------------------------------------------------

library(tidyverse)
library(lubridate)
library(dplyr)
library(ggplot2)
library(readr)
library(moments)
library(scales)

# ------------------------------------------------------------
# IMPORTACIÓN DEL DATASET
# ------------------------------------------------------------

# Se importa el archivo original.
#
# Los valores "", "NA" y "NULL" se interpretan como datos
# faltantes (NA), debido a que el archivo utiliza estas
# representaciones para indicar ausencia de información.
#
# En esta etapa el dataset únicamente se analiza.
# No se realizan modificaciones o eliminaciones.

hotel_original <- read_csv(
  "data/hotel_bookings_original.csv",
  na = c("", "NA", "NULL"),
  show_col_types = FALSE
)

# ============================================================
# EVALUACIÓN DE LA CALIDAD DE LOS DATOS
# ============================================================


# ------------------------------------------------------------
# COMPLETITUD
# ------------------------------------------------------------

# La completitud evalúa la presencia de valores faltantes.
#
# Para cada variable se calcula:
# - cantidad de valores NA
# - porcentaje de valores NA respecto al total de registros
#
# Finalmente, se muestran únicamente las variables que
# presentan al menos un valor faltante.

tabla_faltantes <- tibble(
  variable = names(hotel_original),
  
  cantidad = colSums(
    is.na(hotel_original)
  ),
  
  porcentaje = round(
    colMeans(
      is.na(hotel_original)
    ) * 100,
    3
  )
) %>%
  filter(cantidad > 0) %>%
  arrange(desc(porcentaje))

# Mostrar resultados de completitud.

tabla_faltantes

# ------------------------------------------------------------
# UNICIDAD
# ------------------------------------------------------------

# La unicidad permite identificar registros exactamente
# repetidos dentro del dataset.
#
# Se calculan:
# - número total de registros
# - cantidad de filas duplicadas exactas
# - porcentaje que representan
# - cantidad de combinaciones de registros distintas
#
# IMPORTANTE:
# La existencia de filas idénticas no demuestra por sí sola
# que sean errores, debido a que el dataset no dispone de un
# identificador único de reserva.

tabla_unicidad <- tibble(
  indicador = c(
    "Registros totales",
    "Filas duplicadas exactas",
    "Porcentaje de duplicados",
    "Registros distintos"
  ),
  
  resultado = c(
    nrow(hotel_original),
    
    sum(
      duplicated(hotel_original)
    ),
    
    round(
      mean(
        duplicated(hotel_original)
      ) * 100,
      2
    ),
    
    nrow(
      distinct(hotel_original)
    )
  )
)

# Mostrar resultados de unicidad.

tabla_unicidad

# ------------------------------------------------------------
# CONSISTENCIA 
# ------------------------------------------------------------

# Filtrar las reservas con menores (niños o bebés) sin ningún adulto

inconsistencia_menores <- hotel_original %>% 
  filter(adults == 0 & (children > 0 | babies > 0))

# Filtrar las reservas con aforo total igual a cero

inconsistencia_cero_total <- hotel_original %>% 
  filter((adults + children + babies) == 0)

# Crear una tabla resumen específica para esta dimensión

tabla_composicion_huéspedes <- tibble(
  Tipo_Inconsistencia = c(
    "Menores (niños/bebés) sin adultos responsables",
    "Aforo total nulo (0 personas en la reserva)"
  ),
  Cantidad_Casos = c(
    nrow(inconsistencia_menores),
    nrow(inconsistencia_cero_total)
  ),
  Criterio_Negocio = c(
    "Violación de norma de seguridad hotelera",
    "Incoherencia lógica de transacción vacía"
  )
)

# Mostrar los resultados

tabla_composicion_huéspedes

# ------------------------------------------------------------

# Filtrar y contar los casos de estancias con cero noches

total_estancias_cero <- sum(
  hotel_original$stays_in_weekend_nights == 0 & hotel_original$stays_in_week_nights == 0, 
  na.rm = TRUE
)

# Crear la estructura formal de tabla para el informe

tabla_estancias_inconsistentes <- tibble(
  Tipo_de_comprobación = c(
    "Estancias con duración de cero noches (ambas variables en 0)"
  ),
  Cantidad_de_Casos = c(
    total_estancias_cero
  )
)

# Mostrar los resultados

tabla_estancias_inconsistentes

# ------------------------------------------------------------

meal_undef <- sum(hotel_original$meal == "Undefined", na.rm = TRUE)
market_undef <- sum(hotel_original$market_segment == "Undefined", na.rm = TRUE)
dist_undef <- sum(hotel_original$distribution_channel == "Undefined", na.rm = TRUE)

# Crear la tabla formal para el informe

tabla_ambiguedades_cat <- tibble(
  Variable = c(
    "Regimen de comidas (meal)",
    "Segmento de mercado (market_segment)",
    "Canal de distribucion (distribution_channel)"
  ),
  Categoria_Evaluada = c("Undefined", "Undefined", "Undefined"),
  Cantidad_de_Casos = c(meal_undef, market_undef, dist_undef)
)

# Mostrar los resultados

tabla_ambiguedades_cat

# ------------------------------------------------------------
# VALIDEZ
# ------------------------------------------------------------

# Cuantificar los problemas de validez

validez_cn <- sum(hotel_original$country == "CN", na.rm = TRUE)
validez_adr_negativa <- sum(hotel_original$adr < 0, na.rm = TRUE)
validez_adr_extrema <- sum(hotel_original$adr > 1000, na.rm = TRUE)
validez_adr_cero <- sum(hotel_original$adr == 0, na.rm = TRUE)

# Crear la tabla formal de validez para el informe

tabla_validez_completa <- tibble(
  Problema_Identificado = c(
    "Código de país con formato incorrecto (CN)",
    "Tarifa diaria promedio (adr) negativa",
    "Tarifa diaria promedio (adr) extrema (> 1000)",
    "Tarifas de alojamiento en cero (adr = 0)"
  ),
  Variable = c("country", "adr", "adr", "adr"),
  Cantidad_Casos = c(validez_cn, validez_adr_negativa, validez_adr_extrema, validez_adr_cero)
)

# Mostrar los resultados

tabla_validez_completa

# ==========================================
# ANÁLISIS UNIVARIADO Y OUTLIERS
# ==========================================

desc_adr <- hotel_original %>%
  summarise(
    Variable = "adr",
    Media = mean(adr, na.rm = TRUE),
    Mediana = median(adr, na.rm = TRUE),
    Desv_Est = sd(adr, na.rm = TRUE),
    Minimo = min(adr, na.rm = TRUE),
    Maximo = max(adr, na.rm = TRUE)
  )
print("--- Medidas Descriptivas: ADR ---")
print(desc_adr)

# Tabla de Frecuencias y Porcentajes por Rangos (Intervalos)

# Creamos cortes para clasificar las tarifas
hotel_original <- hotel_original %>%
  mutate(adr_categoria = cut(adr, 
                             breaks = c(-Inf, 0, 50, 100, 150, 200, 500, Inf), 
                             labels = c("Negativo/Cero", "0 - 50", "50.01 - 100", "100.01 - 150", "150.01 - 200", "200.01 - 500", "Más de 500")))

tabla_freq_adr <- hotel_original %>%
  count(adr_categoria) %>%
  mutate(Porcentaje = (n / sum(n)) * 100)

# Mostrar los resultados
tabla_freq_adr

# Visualizaciones (Histograma y Boxplot)

# Creación del Histograma para la Tarifa Diaria (adr)

hist_adr <- ggplot(hotel_original, aes(x = adr)) +
  geom_histogram(bins = 40, fill = "steelblue", color = "black") +
  labs(
    title = "Análisis Univariado: Histograma de Tarifa Diaria (adr)",
    subtitle = "Distribución asimétrica positiva con fuerte concentración en tarifas bajas y medias",
    x = "Tarifa Diaria Promedio (adr)",
    y = "Frecuencia (Número de Reservas)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(size = 10, color = "gray30")
  )

print(hist_adr)

boxplot_adr <- ggplot(hotel_original, aes(y = adr)) +
  geom_boxplot(fill = "indianred", color = "black") +
  labs(
    title = "Detección de Outliers: Tarifa Diaria (adr)",
    subtitle = "Identificación de valores atípicos extremos (inferiores y superiores)",
    y = "ADR (Unidades Monetarias)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(size = 10, color = "gray30")
  )

print(boxplot_adr)

# ==========================================
# ANÁLISIS UNIVARIADO PARA LEAD_TIME (Anticipación)
# ==========================================

# Medidas descriptivas
desc_lead <- hotel_original %>%
  summarise(
    Variable = "lead_time",
    Media = mean(lead_time, na.rm = TRUE),
    Mediana = median(lead_time, na.rm = TRUE),
    Desv_Est = sd(lead_time, na.rm = TRUE),
    Minimo = min(lead_time, na.rm = TRUE),
    Maximo = max(lead_time, na.rm = TRUE)
  )

print("--- Medidas Descriptivas: Lead Time ---")
print(desc_lead)

# Tabla de Frecuencias y Porcentajes por Rangos de Días

hotel_original <- hotel_original %>%
  mutate(lead_categoria = cut(lead_time, 
                              breaks = c(-Inf, 0, 30, 90, 180, 365, Inf), 
                              labels = c("Mismo día (0)", "1 a 30 días", "31 a 90 días", "91 a 180 días", "181 a 365 días", "Más de 1 año")))

tabla_freq_lead <- hotel_original %>%
  count(lead_categoria) %>%
  mutate(Porcentaje = (n / sum(n)) * 100)

print("--- Tabla de Frecuencias y Porcentajes: Lead Time ---")
print(tabla_freq_lead)

# Visualizaciones (Histograma y Boxplot)

hist_lead_time <- ggplot(hotel_original, aes(x = lead_time)) +
  geom_histogram(bins = 40, fill = "cornflowerblue", color = "black") +
  labs(
    title = "Análisis Univariado: Histograma de Tiempo de Anticipación (lead_time)",
    subtitle = "Distribución asimétrica positiva con concentración en reservas a corto plazo",
    x = "Tiempo de Anticipación (Días)",
    y = "Frecuencia (Número de Reservas)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(size = 10, color = "gray30")
  )

# Mostrar los resultados
print(hist_lead_time)


boxplot_lead <- ggplot(hotel_original, aes(y = lead_time)) +
  geom_boxplot(fill = "lightblue", color = "black") +
  labs(
    title = "Detección de Outliers: Tiempo de Anticipación (lead_time)",
    subtitle = "Identificación de valores atípicos superiores por reservas a largo plazo",
    y = "Días de Anticipación"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(size = 10, color = "gray30")
  )


# Mostrar los resultados
print(boxplot_lead)

# ==============================================================================
# PROCESO DE LIMPIEZA Y PREPARACIÓN DE DATOS (GENERACIÓN DE hotel_preparado)
# ==============================================================================

hotel_preparado <- hotel_original %>%
  #Unicidad: Eliminación de filas duplicadas exactas
  distinct() %>%
  #Validez: Exclusión de valores atípicos y erróneos críticos en la tarifa (adr)
  filter(adr >= 0 & adr < 5000)

# Consistencia / Errores Categóricos: Recodificar "Undefined" a NA en variables clave
hotel_preparado <- hotel_preparado %>%
  mutate(
    meal = na_if(meal, "Undefined"),
    market_segment = na_if(market_segment, "Undefined"),
    distribution_channel = na_if(distribution_channel, "Undefined")
  )

# Tipos de datos: Conversión de variables a factor y formato de fecha
hotel_preparado <- hotel_preparado %>%
  mutate(
    hotel = as.factor(hotel),
    is_canceled = as.factor(is_canceled),
    meal = as.factor(meal),
    market_segment = as.factor(market_segment),
    distribution_channel = as.factor(distribution_channel),
    reservation_status = as.factor(reservation_status),
    customer_type = as.factor(customer_type),
    deposit_type = as.factor(deposit_type),
    reservation_status_date = as.Date(reservation_status_date)
  )


# ==============================================================================
# EXPORTAR EL NUEVO DATASET PREPARADO 
# ==============================================================================
# Se guarda estrictamente en la carpeta 'data/' sin modificar el archivo original
write.csv(hotel_preparado, "data/hotel_bookings_preparado.csv", row.names = FALSE)

# ==============================================================================
# ANÁLISIS BIVARIADO PARA RESPONDER PREGUNTAS ANALÍTICAS
# ==============================================================================

ggplot(hotel_preparado, aes(x = hotel, fill = is_canceled)) +
  geom_bar(position = "fill") +
  scale_y_continuous(labels = percent) +
  labs(
    title = "Proporción de Cancelaciones según Tipo de Hotel",
    subtitle = "Comparativa porcentual entre City Hotel y Resort Hotel",
    x = "Tipo de Hotel",
    y = "Proporción de Reservas",
    fill = "Estado (0 = No Cancelado, 1 = Cancelado)"
  ) +
  theme_minimal() +
  scale_fill_manual(values = c("#2b5c8f", "#d95f02"))




demanda_mensual <- hotel_preparado %>%
  count(hotel, arrival_date_month)

ggplot(demanda_mensual, aes(x = arrival_date_month, y = n, group = hotel, color = hotel)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 2.5) +
  labs(
    title = "Evolución de la Demanda de Reservas a lo largo del Año",
    subtitle = "Distribución mensual de la demanda según tipo de hotel",
    x = "Mes de Llegada",
    y = "Número de Reservas",
    color = "Tipo de Hotel"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  scale_color_manual(values = c("#1b9e77", "#7570b3"))

prop.table(table(hotel_original$hotel)) * 100





