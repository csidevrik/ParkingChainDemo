package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"
)

type Vehiculo struct {
	Placa       string    `json:"placa"`
	HoraEntrada time.Time `json:"hora_entrada"`
}

var (
	vehiculosActivos = make(map[string]Vehiculo)
	mutex            sync.Mutex
)

func ingresoHandler(w http.ResponseWriter, r *http.Request) {
	var v Vehiculo
	err := json.NewDecoder(r.Body).Decode(&v)
	if err != nil || v.Placa == "" {
		http.Error(w, "Placa inválida", http.StatusBadRequest)
		return
	}

	mutex.Lock()
	defer mutex.Unlock()

	if _, existe := vehiculosActivos[v.Placa]; existe {
		http.Error(w, "Vehículo ya ingresado", http.StatusConflict)
		return
	}

	v.HoraEntrada = time.Now()
	vehiculosActivos[v.Placa] = v

	w.WriteHeader(http.StatusCreated)
	fmt.Fprintf(w, "Vehículo %s ingresado", v.Placa)
}

func salidaHandler(w http.ResponseWriter, r *http.Request) {
	type Salida struct {
		Placa string `json:"placa"`
	}
	var s Salida
	err := json.NewDecoder(r.Body).Decode(&s)
	if err != nil || s.Placa == "" {
		http.Error(w, "Placa inválida", http.StatusBadRequest)
		return
	}

	mutex.Lock()
	defer mutex.Unlock()

	v, existe := vehiculosActivos[s.Placa]
	if !existe {
		http.Error(w, "Vehículo no encontrado", http.StatusNotFound)
		return
	}

	duracion := time.Since(v.HoraEntrada)
	minutos := int(duracion.Minutes())
	costo := minutos

	delete(vehiculosActivos, s.Placa)

	respuesta := map[string]interface{}{
		"placa":   s.Placa,
		"minutos": minutos,
		"costo":   fmt.Sprintf("$%.2f", float64(costo)/100),
	}
	json.NewEncoder(w).Encode(respuesta)
}

func estadoHandler(w http.ResponseWriter, r *http.Request) {
	mutex.Lock()
	defer mutex.Unlock()

	var placas []string
	for placa := range vehiculosActivos {
		placas = append(placas, placa)
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"vehiculos_activos": placas,
		"ocupados":          len(vehiculosActivos),
	})
}

func main() {
	http.HandleFunc("/ingreso", ingresoHandler)
	http.HandleFunc("/salida", salidaHandler)
	http.HandleFunc("/estado", estadoHandler)

	fmt.Println("Servidor parqueadero en puerto 8080...")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
