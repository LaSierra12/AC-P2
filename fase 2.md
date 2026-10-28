
## Resumen Teórico y Mecánica del Predictor AGREE

El predictor **AGREE** es un predictor dinámico que busca reducir el _aliasing_ (colisiones negativas en la PHT) convirtiendo las colisiones en neutras o beneficiosas mediante un *bit de sesgo (**biasing bit** $S$).

#### 🏛️ Las 4 Estructuras del Predictor:

1. **GBHR (Global Branch History Register)**: Registro de **$g$** bits que almacena el historial global de los últimos $g$ saltos (1 para _Taken_, 0 para _NotTaken_)1.
2. **BTBbis**: Tabla asociativa de $2^b$ entradas (tamaño $Y$) con política de reemplazo **LRU**. Guarda el bit de comportamiento inicial/sesgo $S$ para cada salto visto1.
3. **PHT (Pattern History Table)**: Tabla de $2^c$ entradas (tamaño $X$) con contadores saturados de 2 bits1. Se direcciona indexando $c = i + g$ bits (donde $g$ bits provienen del GBHR e $i$ bits provienen de la dirección de la instrucción de salto)1. Los contadores **no predicen** **Taken/NotTaken** **directamente**, sino si el salto **coincidirá (Agree) o no (Disagree) con el bit de sesgo $S$.**
4. **Lógica de Predicción**: $$\text{Predicción} = \text{PHT}_{\text{msb}} \text{ NXOR } S$$ _(Si el contador indica "coincidir" (_$\text{PHT}_{\text{msb}}=1$_), la predicción es_ $S$_; si indica "no coincidir" (_$\text{PHT}_{\text{msb}}=0$_), la predicción es la opuesta_ $\neg S$_)_.

---

#### ⚙️ Parámetros y Configuraciones Exigidas (5 Variantes)

El comando en SimpleScalar será `-bpred agree -bpred:agree <Y> <X> <g> 0`1. Se deben simular 5 combinaciones $(Y, X, g)$ sobre los 5 benchmarks1:

|Configuración|BTBbis ($Y = 2^b$)|PHT ($X = 2^c$)|GBHR ($g$)|Bits dirección PC ($i = c - g$)|
|---|---|---|---|---|
|**agree_4_8_2**|4|8 ($c=3$)|2|1|
|**agree_8_32_3**|8|32 ($c=5$)|3|2|
|**agree_16_128_4**|16|128 ($c=7$)|4|3|
|**agree_32_512_6**|32|512 ($c=9$)|6|3|
|**agree_64_2048_8**|64|2048 ($c=11$)|8|3|

---

#### 🗺️ Plan de Ejecución de la Fase 2

Dividiremos la Fase 2 en **4 Pasos metódicos**:

###### **Paso 1: Modificación del Código C en SimpleScalar**

Inspirándonos en la estructura del predictor `2lev` ya existente:

1. **bpred.h**:
    - Añadir `BPredAgree` a la lista `enum bpred_class`.
    - Definir la estructura de datos del predictor AGREE (punteros a GBHR, BTBbis con campo $S$ y LRU, y tabla PHT).
2. **sim-outorder.c**:
    - Registrar la opción `-bpred:agree` en `sim_reg_options()`.
    - Declarar variables de configuración `agree_config` y `agree_nelt`.
    - Añadir la lectura del flag en `sim_check_options()` e invocar `bpred_create(BPredAgree, ...)`.
3. **bpred.c**:
    - **bpred_create()** **/** **bpred_dir_create()**: Reservar memoria e inicializar estructuras a '1' (para que la predicción inicial sea _Taken_).
    - **bpred_dir_lookup()**: Calcular el índice de la PHT, realizar la búsqueda asociativa en el BTBbis, y calcular la predicción mediante $\text{PHT}_{\text{msb}} \text{ NXOR } S$.
    - **bpred_update()**: Actualizar GBHR, actualizar BTBbis (en caso de _MISS_, insertar nuevo salto con LRU) e incrementar/decrementar el contador saturado de la PHT según si el resultado real coincidió o no con $S$.
4. **Recompilador**: Ejecutar `make` en la carpeta de SimpleScalar.

###### **Paso 2: Validación Rápida (Smoke Test)**

- Probar una ejecución corta (ej. `-max:inst 10000`) utilizando `-bpred agree -bpred:agree 16 128 4 0` para comprobar que el simulador no lanza _segmentation fault_ ni errores de memoria y que imprime correctamente las estadísticas en la salida1.

###### **Paso 3: Automatización de Simulaciones (****ejecutar_fase2.sh****)**

- Crear el script de Bash para ejecutar las **25 simulaciones** (5 configuraciones AGREE x 5 benchmarks) con la configuración estándar de memoria (`-mem:width 32 -mem:lat 300 2 -fastfwd 100000000 -max:inst 100000000`)1.
- Extraer automáticamente `sim_IPC` y `bpred_dir_rate` a los ficheros CSV formateados para Excel1.

###### **Paso 4: Análisis Comparativo y Cuestiones del Informe**

- Integrar los resultados de AGREE en las gráficas comparativas junto a las 24 configuraciones de la Fase 1.
- Responder a la pregunta teórica del enunciado: **¿A qué predictor clásico (GAg, PAg, GAp, PAp) se parece más el predictor AGREE y con qué parámetros?**


---

# APUNTES LAB
AGREE-> procesador que comparte estructura con la mayoria pero tiene la diferencia de BTBbis

![[esquema.png]]
 BGHR= global history register
 PHT= entradas de 2 bits=pattern history table
 addicion de BTBbis= es bis porque es el segundo. Para no editar el primer BTB se crea otro para mayor simplicidad a la hora de trabajar con el simplescalar
 cada entry representa una branch. cada branch tiene su propia entrada. any branch can be stored in any place. so we recorrer the whole table looking for it.
### two level predictor
implementa dos niveles de informacion.
PaBHT y PHT

UNDERTAND HOW 2 LEVEL PRED WORKS AND HOW 1 LEVEL WORK
WHAT NEW LINES/SENTENCES WE HAVE TO IMPLEMENT TO SIMULATE THE PREDICTOR  

