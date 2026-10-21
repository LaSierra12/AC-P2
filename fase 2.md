Cuando quieras, podemos pasar a la **Fase 2: implementación del predictor AGREE** en SimpleScalar. Sería:

1. **Modificar `bpred.h`**: añadir `BPredAgree` al enum y las variables nuevas en `struct bpred_dir_t` (`gbhr`, `btbbis_tag[]`, `btbbis_bit[]`, `btbbis_lru[]`, `pht[]`).
    
2. **Modificar `bpred.c`**:
    
    - `bpred_dir_create`: reservar e inicializar todo a `1` (predicción inicial = Taken).
        
    - `bpred_dir_lookup`: buscar en `btbbis` (asociativa, LRU), calcular `i = c − g`, indexar `pht[concat(gbhr, @branch bits)]`, devolver `NXOR(pht_msb, btbbis_bit)`.
        
    - `bpred_update`: actualizar `gbhr`, `pht` (contador saturado respecto al bit del `btbbis`), y en MISS insertar en `btbbis` con LRU.
        
    - `bpred_config` y `bpred_reg_stats`: nuevos `case`.
        
3. **Modificar `sim-outorder.c`**: registrar `-bpred:agree <Y> <X> <g> 0` y llamar a `bpred_create` con los parámetros.
    
4. **Recompilar** y ejecutar las 5 configuraciones `(4-8), (8-32), (16-128), (32-512), (64-2048)` con `g ∈ {2,3,4,6,8}`.
    
5. **Tarea 1**: identificar a qué predictor de `{Gag, Pag, Gap, Pap}` se parece AGREE. Spoiler: AGREE es estructuralmente un **GAg con sesgo** (biasing bit por rama), porque combina historia global (`g`) con dirección de rama (`i`) en la PHT y usa un bit de sesgo por rama. Con `g=0` y `i` bits del PC, se reduce a un **bimodal**; con `i` bits del PC y sin sesgo, sería `GAg`/`Gselect`. La comparación cuantitativa lo confirmará.
    
6. **Tarea 2**: simular AGREE vs. el predictor identificado y comparar `%Acierto` e IPC.