# Live Data Feed System: Real-Time Stock Price Stream

Simplfy Design
<img width="1023" height="479" alt="image" src="https://github.com/user-attachments/assets/9baebaf1-b94a-43a4-a14a-bfb0b19cc5f3" />
 

### Scenario:
Design and implement a real-time system that receives stock price updates from a simulated external service (e.g., a mock API or random generator). The system must stream updates to clients, process these updates, and allow users to subscribe to specific stock symbols for Real-time updates.

### Instructions:
#### Stock Price Stream:

● Build a simple process that simulates receiving real-time stock price updates for multiple stock symbols.

● The stock prices can be randomly generated or fetched periodically from a mock API. For each update, it should be broadcasted to subscribers who are interested in that stock symbol.

#### Client Simulation:
● For this exercise, a simulated client can be a simple process that subscribes
to a stock symbol and prints any updates received. This simulates how clients
(e.g., browsers, other services) would receive real-time data.

#### Error Handling and Fault Tolerance:
● Ensure that the system can recover gracefully from failures. For example, a
stock price update process can crash, but the system should keep running
without affecting the rest of the operations.

