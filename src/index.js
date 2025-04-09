import { Elm } from './Main.elm';
import '../public/style.css';

// Get API key from environment variables
const apiKey = process.env.WEATHER_API_KEY;

// Initialize Elm application
const app = Elm.Main.init({
  node: document.getElementById('elm-app'),
  flags: {
    // You can pass any initial data as flags here
  }
});

// Set up port for weather API requests
app.ports.requestWeather.subscribe(function(city) {
  const url = `https://api.openweathermap.org/data/2.5/weather?q=${encodeURIComponent(city)}&units=metric&appid=${apiKey}`;
  
  fetch(url)
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! Status: ${response.status}`);
      }
      return response.json();
    })
    .then(data => {
      console.log('Weather data received:', data);
      app.ports.receiveWeather.send({
        status: 'success',
        data: data
      });
    })
    .catch(error => {
      console.error('Error fetching weather:', error);
      app.ports.receiveWeather.send({
        status: 'error',
        error: error.message
      });
    });
});