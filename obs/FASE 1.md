# Plan de análisis para la Fase 1

Ya tienes los datos. Ahora falta transformarlos en **entregables**. La práctica pide tres cosas obligatorias:

1. **Informe PDF** (con gráficas + análisis escrito)
    
2. **Vídeo resumen** (defensa)
    
3. **ZIP con scripts + resultados** (subir a Moodle antes de la entrevista)
    

---

## 1. Gráficas que debes generar (≈ 12)

La práctica pide explícitamente:

|#|Gráfica|Fuente|Eje X|Series|
|---|---|---|---|---|
|1|**Estáticos (barras)**|`Resultados_Completos_Fase1.csv`|NT / T / P|5 benchmarks + Media|
|2|**Bimodal IPC**|`Resultados_IPC.csv`|8, 32, 128, 512, 2048|ammp, bzip2, gap, swim, vpr, Media|
|3|**Bimodal %Acierto**|`Resultados_Tasa_Acierto.csv`|8, 32, 128, 512, 2048|ídem|
|4|**Gshare IPC**|`Resultados_IPC.csv`|ídem|ídem|
|5|**Gshare %Acierto**|`Resultados_Tasa_Acierto.csv`|ídem|ídem|
|6|**Gag IPC**|`Resultados_IPC.csv`|ídem|ídem|
|7|**Gag %Acierto**|`Resultados_Tasa_Acierto.csv`|ídem|ídem|
|8|**Pag IPC**|`Resultados_IPC.csv`|4, 16, 64, 256, 1024, 2048|ídem|
|9|**Pag %Acierto**|`Resultados_Tasa_Acierto.csv`|ídem|ídem|
|10|**Resumen 7 predictores IPC**|`Resultados_IPC.csv`|tamaño PHT (escala numérica)|7 líneas (una por predictor)|
|11|**Resumen 7 predictores %Acierto**|`Resultados_Tasa_Acierto.csv`|ídem|ídem|

Opcional: 12. **Barra estáticos IPC** (si no combinas 1 en una sola).