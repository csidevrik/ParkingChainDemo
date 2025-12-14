package main

import (
    "encoding/json"
    "fmt"
    "io"
    "log"
    "net/http"
)

var parqueaderos = []string{
    "http://parqueadero1:8080/estado",
    "http://parqueadero2:8080/estado",
}

func consultarEstado(url string) (map[string]interface{}, error) {
    resp, err := http.Get(url)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()

    var estado map[string]interface{}
    body, _ := io.ReadAll(resp.Body)
    json.Unmarshal(body, &estado)
    return estado, nil
}

func resumenHandler(w http.ResponseWriter, r *http.Request) {
    resumen := make(map[string]interface{})
    totalOcupados := 0

    for i, url := range parqueaderos {
        estado, err := consultarEstado(url)
        nombre := fmt.Sprintf("parqueadero%d", i+1)
        if err != nil {
            resumen[nombre] = "desconectado"
            continue
        }

        ocupados := int(estado["ocupados"].(float64))
        totalOcupados += ocupados
        resumen[nombre] = estado
    }

    resumen["total_ocupados"] = totalOcupados
    json.NewEncoder(w).Encode(resumen)
}

func main() {
    http.HandleFunc("/resumen", resumenHandler)
    fmt.Println("Coordinador escuchando en puerto 8083...")
    log.Fatal(http.ListenAndServe(":8083", nil))
}
