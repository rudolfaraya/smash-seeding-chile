import { Controller } from "@hotwired/stimulus"

// Conectar a los elementos con data-controller="stats"
export default class extends Controller {
  static targets = [
    "regionChart", 
    "modalityChart", 
    "yearChart", 
    "sizeChart", 
    "activePlayersChart"
  ]

  static values = {
    regionData: Object,
    modalityData: Object,
    yearData: Object,
    sizeData: Object,
    activePlayersData: Array
  }

  connect() {
    console.log('Stats controller connected!')
    console.log('Data values:', {
      region: this.regionDataValue,
      modality: this.modalityDataValue,
      year: this.yearDataValue,
      size: this.sizeDataValue,
      players: this.activePlayersDataValue
    })
    
    // Esperar a que Chart.js esté disponible globalmente
    if (typeof Chart !== 'undefined') {
      this.initializeWithChart()
    } else {
      // Esperar un momento para que Chart.js se cargue
      setTimeout(() => {
        if (typeof Chart !== 'undefined') {
          this.initializeWithChart()
        } else {
          console.error('Chart.js not available globally')
        }
      }, 500)
    }
  }

  initializeWithChart() {
    console.log('Chart.js is available:', typeof Chart)
    this.Chart = Chart
    
    // Configuración global para Chart.js
    this.Chart.defaults.color = '#cbd5e1' // slate-300
    this.Chart.defaults.borderColor = '#475569' // slate-600
    this.Chart.defaults.backgroundColor = 'rgba(239, 68, 68, 0.1)' // red-500 with opacity

    // Paleta de colores
    this.colors = {
      primary: '#ef4444', // red-500
      secondary: '#3b82f6', // blue-500
      success: '#10b981', // green-500
      warning: '#f59e0b', // yellow-500
      info: '#06b6d4', // cyan-500
      purple: '#8b5cf6', // purple-500
      pink: '#ec4899', // pink-500
      indigo: '#6366f1', // indigo-500
    }

    this.initializeCharts()
  }

  disconnect() {
    // Limpiar gráficos cuando se desconecta el controlador
    if (this.charts) {
      Object.values(this.charts).forEach(chart => {
        if (chart) chart.destroy()
      })
    }
  }

  initializeCharts() {
    if (!this.Chart) {
      console.error('Chart.js not loaded')
      return
    }
    
    // Validar que los datos sean objetos válidos
    if (!this.regionDataValue || typeof this.regionDataValue !== 'object') {
      console.error('Invalid regionDataValue:', this.regionDataValue)
      return
    }
    
    if (!this.yearDataValue || typeof this.yearDataValue !== 'object') {
      console.error('Invalid yearDataValue:', this.yearDataValue)
      return
    }
    
    if (!this.sizeDataValue || typeof this.sizeDataValue !== 'object') {
      console.error('Invalid sizeDataValue:', this.sizeDataValue)
      return
    }
    
    if (!this.activePlayersDataValue || !Array.isArray(this.activePlayersDataValue)) {
      console.error('Invalid activePlayersDataValue:', this.activePlayersDataValue)
      return
    }
    
    this.charts = {}
    
    // Configuración común para leyendas (abajo)
    const compactLegend = {
      position: 'bottom',
      labels: {
        padding: 10,
        usePointStyle: true,
        boxWidth: 12,
        font: {
          size: 11
        }
      }
    }
    
    // Configuración para leyendas a la derecha (gráficos de torta)
    const rightLegend = {
      position: 'right',
      labels: {
        padding: 15,
        usePointStyle: true,
        boxWidth: 12,
        font: {
          size: 11
        }
      }
    }
    
    // Gráfico de distribución por región
    if (this.hasRegionChartTarget) {
      this.charts.region = new this.Chart(this.regionChartTarget, {
        type: 'doughnut',
        data: {
          labels: Object.keys(this.regionDataValue),
          datasets: [{
            data: Object.values(this.regionDataValue),
            backgroundColor: [
              this.colors.primary,
              this.colors.secondary,
              this.colors.success,
              this.colors.warning,
              this.colors.info,
              this.colors.purple,
              this.colors.pink,
              this.colors.indigo
            ],
            borderWidth: 2,
            borderColor: '#1e293b'
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: rightLegend
          }
        }
      })
    }

    // Gráfico de modalidades (Online vs Presencial)
    if (this.hasModalityChartTarget) {
      this.charts.modality = new this.Chart(this.modalityChartTarget, {
        type: 'pie',
        data: {
          labels: Object.keys(this.modalityDataValue),
          datasets: [{
            data: Object.values(this.modalityDataValue),
            backgroundColor: [this.colors.secondary, this.colors.success],
            borderWidth: 2,
            borderColor: '#1e293b'
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: rightLegend
          }
        }
      })
    }

    // Gráfico de torneos por año
    if (this.hasYearChartTarget) {
      this.charts.year = new this.Chart(this.yearChartTarget, {
        type: 'line',
        data: {
          labels: Object.keys(this.yearDataValue),
          datasets: [{
            label: 'Torneos',
            data: Object.values(this.yearDataValue),
            borderColor: this.colors.primary,
            backgroundColor: this.colors.primary + '20',
            tension: 0.4,
            fill: true
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          scales: {
            y: {
              beginAtZero: true,
              grid: {
                color: '#374151'
              },
              ticks: {
                font: {
                  size: 11
                }
              }
            },
            x: {
              grid: {
                color: '#374151'
              },
              ticks: {
                font: {
                  size: 11
                }
              }
            }
          },
          plugins: {
            legend: {
              display: false
            }
          }
        }
      })
    }



    // Gráfico de distribución por tamaño
    if (this.hasSizeChartTarget) {
      this.charts.size = new this.Chart(this.sizeChartTarget, {
        type: 'bar',
        data: {
          labels: Object.keys(this.sizeDataValue),
          datasets: [{
            label: 'Cantidad de Torneos',
            data: Object.values(this.sizeDataValue),
            backgroundColor: [
              this.colors.success,
              this.colors.secondary,
              this.colors.warning,
              this.colors.purple,
              this.colors.primary
            ],
            borderColor: [
              this.colors.success,
              this.colors.secondary,
              this.colors.warning,
              this.colors.purple,
              this.colors.primary
            ],
            borderWidth: 1
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          scales: {
            y: {
              beginAtZero: true,
              grid: {
                color: '#374151'
              },
              ticks: {
                font: {
                  size: 11
                }
              }
            },
            x: {
              grid: {
                display: false
              },
              ticks: {
                font: {
                  size: 10
                }
              }
            }
          },
          plugins: {
            legend: {
              display: false
            }
          }
        }
      })
    }

    // Gráfico de jugadores más activos
    if (this.hasActivePlayersChartTarget) {
      this.charts.activePlayers = new this.Chart(this.activePlayersChartTarget, {
        type: 'bar',
        data: {
          labels: this.activePlayersDataValue.map(p => p.name),
          datasets: [{
            label: 'Torneos',
            data: this.activePlayersDataValue.map(p => p.participations),
            backgroundColor: this.colors.primary,
            borderColor: this.colors.primary,
            borderWidth: 1
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          indexAxis: 'y',
          scales: {
            y: {
              beginAtZero: true,
              grid: {
                color: '#374151'
              },
              ticks: {
                font: {
                  size: 10
                }
              }
            },
            x: {
              grid: {
                color: '#374151'
              },
              ticks: {
                font: {
                  size: 11
                }
              }
            }
          },
          plugins: {
            legend: {
              display: false
            }
          }
        }
      })
    }
  }
} 