package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
)

var parqueaderos = []string{
	"http://parqueadero1:8080",
	"http://parqueadero2:8080",
}

func ingreso(placa string, id int) error {
	url := fmt.Sprintf("%s/ingreso", parqueaderos[id])
	data := map[string]string{"placa": placa}
	return postJSON(url, data)
}

func salida(placa string, id int) (string, error) {
	url := fmt.Sprintf("%s/salida", parqueaderos[id])
	data := map[string]string{"placa": placa}
	resp, err := postJSONResponse(url, data)
	return resp, err
}

func estado(id int) (string, error) {
	url := fmt.Sprintf("%s/estado", parqueaderos[id])
	resp, err := http.Get(url)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	return string(body), nil
}

func postJSON(url string, payload interface{}) error {
	body, _ := json.Marshal(payload)
	_, err := http.Post(url, "application/json", bytes.NewBuffer(body))
	return err
}

func postJSONResponse(url string, payload interface{}) (string, error) {
	body, _ := json.Marshal(payload)
	resp, err := http.Post(url, "application/json", bytes.NewBuffer(body))
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(resp.Body)
	return string(b), nil
}

func dashboardHandler(w http.ResponseWriter, r *http.Request) {
	html := `
    <h1>Dashboard Parqueadero</h1>
    <form method="POST" action="/ingresar">
        <input name="placa" placeholder="Placa"/>
        <select name="parqueadero">
            <option value="0">Parqueadero 1</option>
            <option value="1">Parqueadero 2</option>
        </select>
        <button type="submit">Ingresar</button>
    </form>

    <form method="POST" action="/salir">
        <input name="placa" placeholder="Placa"/>
        <select name="parqueadero">
            <option value="0">Parqueadero 1</option>
            <option value="1">Parqueadero 2</option>
        </select>
        <button type="submit">Salir</button>
    </form>

    <form method="GET" action="/estado">
        <select name="parqueadero">
            <option value="0">Parqueadero 1</option>
            <option value="1">Parqueadero 2</option>
        </select>
        <button type="submit">Ver Estado</button>
    </form>
    `
	w.Write([]byte(html))
}

func ingresarHandler(w http.ResponseWriter, r *http.Request) {
	r.ParseForm()
	placa := r.FormValue("placa")
	id := r.FormValue("parqueadero")
	pid := 0
	if id == "1" {
		pid = 1
	}
	err := ingreso(placa, pid)
	if err != nil {
		http.Error(w, "Error al ingresar vehículo", 500)
		return
	}
	http.Redirect(w, r, "/", 302)
}

func salirHandler(w http.ResponseWriter, r *http.Request) {
	r.ParseForm()
	placa := r.FormValue("placa")
	id := r.FormValue("parqueadero")
	pid := 0
	if id == "1" {
		pid = 1
	}
	result, err := salida(placa, pid)
	if err != nil {
		http.Error(w, "Error al registrar salida", 500)
		return
	}
	w.Write([]byte("<pre>" + result + "</pre><br><a href='/'>Volver</a>"))
}

func estadoHandler(w http.ResponseWriter, r *http.Request) {
	id := r.URL.Query().Get("parqueadero")
	pid := 0
	if id == "1" {
		pid = 1
	}
	result, err := estado(pid)
	if err != nil {
		http.Error(w, "Error al obtener estado", 500)
		return
	}
	w.Write([]byte("<pre>" + result + "</pre><br><a href='/'>Volver</a>"))
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8081"
	}

	http.HandleFunc("/", dashboardHandler)
	http.HandleFunc("/ingresar", ingresarHandler)
	http.HandleFunc("/salir", salirHandler)
	http.HandleFunc("/estado", estadoHandler)

	fmt.Println("Dashboard escuchando en puerto " + port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
