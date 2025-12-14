# Crear estructura de proyecto ParqueaderoChain con contenido base

$root = "ParqueaderoChain"

# Carpetas a crear
$folders = @(
    "$root/dashboard",
    "$root/parqueadero",
    "$root/coordinador"
)

# Archivos vacíos (README y coordinador)
$emptyFiles = @(
    "$root/coordinador/main.go",
    "$root/Dockerfile.coordinador",
    "$root/README.md"
)

# Crear carpetas
foreach ($folder in $folders) {
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder | Out-Null
    }
}

# Crear archivos vacíos
foreach ($file in $emptyFiles) {
    if (-not (Test-Path $file)) {
        New-Item -ItemType File -Path $file | Out-Null
    }
}

# ==== parqueadero/main.go ====
$parqueaderoCode = @"
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
"@
Set-Content -Path "$root/parqueadero/main.go" -Value $parqueaderoCode

# ==== Dockerfile.parqueadero ====
$dockerfileParqueadero = @"
FROM fedora:latest
RUN dnf install -y golang git && dnf clean all
WORKDIR /app
COPY ./parqueadero /app
RUN go build -o parqueadero .
EXPOSE 8080
CMD ["./parqueadero"]
"@
Set-Content -Path "$root/Dockerfile.parqueadero" -Value $dockerfileParqueadero

# ==== dashboard/main.go ====
$dashboardCode = @"
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
"@
Set-Content -Path "$root/dashboard/main.go" -Value $dashboardCode

# ==== Dockerfile.dashboard ====
$dockerfileDashboard = @"
FROM fedora:latest
RUN dnf install -y golang && dnf clean all
WORKDIR /app
COPY ./dashboard /app
RUN go build -o dashboard .
EXPOSE 8081
CMD ["./dashboard"]
"@
Set-Content -Path "$root/Dockerfile.dashboard" -Value $dockerfileDashboard

# ==== docker-compose.yml ====
$compose = @"
version: '3.9'
networks:
  parqueo_net:
    driver: bridge

services:
  parqueadero1:
    build:
      context: .
      dockerfile: Dockerfile.parqueadero
    container_name: parqueadero1
    networks:
      - parqueo_net
    ports:
      - "8080:8080"

  parqueadero2:
    build:
      context: .
      dockerfile: Dockerfile.parqueadero
    container_name: parqueadero2
    networks:
      - parqueo_net
    ports:
      - "8081:8080"

  dashboard:
    build:
      context: .
      dockerfile: Dockerfile.dashboard
    container_name: dashboard
    networks:
      - parqueo_net
    ports:
      - "8082:8081"
"@
Set-Content -Path "$root/docker-compose.yml" -Value $compose
# ==== coordinador/main.go ====
$coordinadorCode = @"
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
"@
Set-Content -Path "$root/coordinador/main.go" -Value $coordinadorCode

# ==== Dockerfile.coordinador ====
$dockerfileCoordinador = @"
FROM fedora:latest
RUN dnf install -y golang && dnf clean all
WORKDIR /app
COPY ./coordinador /app
RUN go build -o coordinador .
EXPOSE 8083
CMD ["./coordinador"]
"@
Set-Content -Path "$root/Dockerfile.coordinador" -Value $dockerfileCoordinador

# Agregar coordinador al final de docker-compose.yml
$coordinadorCompose = @"
  coordinador:
    build:
      context: .
      dockerfile: Dockerfile.coordinador
    container_name: coordinador
    networks:
      - parqueo_net
    ports:
      - "8083:8083"
"@
Add-Content -Path "$root/docker-compose.yml" -Value $coordinadorCompose

Write-Host "✅ Coordinador agregado con lógica de resumen general."


Write-Host "✅ Proyecto ParqueaderoChain creado con código inicial."

