import Chart from 'chart.js/auto';
import 'chartjs-adapter-date-fns';

const ChartHook = {
  mounted() {
    this.initChart(this.el);
    
    // CORREÇÃO: Lida com o evento que agora envia 'data' e 'symbol'
    this.handleEvent("update_chart", ({data, symbol}) => {
      this.updateChart(this.chart, data, symbol);
    });
  },
  
  initChart(el) {
    const ctx = el.getContext('2d');
    const symbol = el.dataset.symbol;
    
    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        datasets: [{
          label: symbol,
          data: [],
          borderColor: 'rgb(75, 192, 192)',
          tension: 0.1,
          fill: false
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          x: {
            type: 'time',
            time: {
              unit: 'second', // Ajustado para melhor visualização de dados em tempo real
              tooltipFormat: 'HH:mm:ss'
            },
            title: {
              display: true,
              text: 'Time'
            }
          },
          y: {
            title: {
              display: true,
              text: 'Price'
            }
          }
        },
        plugins: {
          legend: {
            display: true
          },
          tooltip: {
            mode: 'index',
            intersect: false
          }
        }
      }
    });
  },
  
  // CORREÇÃO: A função agora aceita 'symbol' para atualizar o label do gráfico
  updateChart(chart, newData, symbol) {
    if (newData) {
      // Atualiza o label do dataset se um novo símbolo for fornecido
      if (symbol) {
        chart.data.datasets[0].label = symbol;
      }
      chart.data.datasets[0].data = newData;
    }
    
    // 'none' previne a animação, ideal para atualizações em tempo real
    chart.update('none'); 
  },
  
  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  }
};

export default ChartHook;
