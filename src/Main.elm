port module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Decode exposing (Decoder, field, string, float)
import Json.Encode as Encode
import Task
import Time


-- PORTS


-- Send request to JavaScript to fetch weather data
port requestWeather : String -> Cmd msg


-- Receive weather data from JavaScript
port receiveWeather : (Decode.Value -> msg) -> Sub msg


-- MAIN


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


-- MODEL


type alias WeatherData =
    { temperature : Float
    , description : String
    , city : String
    , humidity : Float
    , windSpeed : Float
    }


type Model
    = Loading String
    | Success WeatherData
    | Failure String
    | Initial { cityInput : String }


init : () -> ( Model, Cmd Msg )
init _ =
    ( Initial { cityInput = "" }, Cmd.none )


-- UPDATE


type Msg
    = ReceivedWeatherData Decode.Value
    | SearchCity String
    | SubmitSearch
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ReceivedWeatherData response ->
            case Decode.decodeValue responseDecoder response of
                Ok weatherResponse ->
                    case weatherResponse.status of
                        "success" ->
                            ( Success weatherResponse.data, Cmd.none )

                        _ ->
                            ( Failure weatherResponse.error, Cmd.none )
                
                Err error ->
                    ( Failure (Decode.errorToString error), Cmd.none )

        SearchCity city ->
            case model of
                Initial initialModel ->
                    ( Initial { initialModel | cityInput = city }, Cmd.none )
                
                _ ->
                    ( Initial { cityInput = city }, Cmd.none )

        SubmitSearch ->
            case model of
                Initial { cityInput } ->
                    if String.trim cityInput == "" then
                        ( model, Cmd.none )
                    else
                        ( Loading cityInput, requestWeather cityInput )
                
                _ ->
                    ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    receiveWeather ReceivedWeatherData


-- VIEW


view : Model -> Html Msg
view model =
    div [ class "container" ]
        [ h1 [] [ text "Elm Weather App" ]
        , div [ class "search-container" ]
            [ input 
                [ placeholder "Enter city name"
                , onInput SearchCity
                , value (getCityInput model)
                , onEnter SubmitSearch
                ] 
                []
            , button [ onClick SubmitSearch ] [ text "Get Weather" ]
            ]
        , viewWeather model
        ]


-- Helper function to extract city input from the model
getCityInput : Model -> String
getCityInput model =
    case model of
        Initial { cityInput } ->
            cityInput
        
        Loading city ->
            city
        
        _ ->
            ""


-- Helper for handling Enter key presses
onEnter : Msg -> Attribute Msg
onEnter msg =
    let
        isEnter code =
            if code == 13 then
                Decode.succeed msg
            else
                Decode.fail "not ENTER"
    in
    on "keydown" (Decode.andThen isEnter (Decode.field "keyCode" Decode.int))


viewWeather : Model -> Html Msg
viewWeather model =
    case model of
        Initial _ ->
            div [ class "message" ] [ text "Enter a city to get started" ]

        Loading city ->
            div [ class "message" ] [ text ("Loading weather for " ++ city ++ "...") ]

        Success weather ->
            div [ class "weather-container" ]
                [ h2 [] [ text weather.city ]
                , div [ class "temperature" ] [ text (String.fromFloat weather.temperature ++ "°C") ]
                , div [ class "description" ] [ text weather.description ]
                , div [ class "details" ]
                    [ div [] [ text ("Humidity: " ++ String.fromFloat weather.humidity ++ "%") ]
                    , div [] [ text ("Wind: " ++ String.fromFloat weather.windSpeed ++ " m/s") ]
                    ]
                ]

        Failure error ->
            div [ class "error" ] [ text ("Error: " ++ error) ]


-- DECODERS


-- Decoder for the success/error structure returned by our JavaScript
type alias WeatherResponse =
    { status : String
    , data : WeatherData
    , error : String
    }


responseDecoder : Decoder WeatherResponse
responseDecoder =
    Decode.map3 WeatherResponse
        (field "status" string)
        (Decode.oneOf
            [ field "data" weatherDecoder
            , Decode.succeed { temperature = 0, description = "", city = "", humidity = 0, windSpeed = 0 }
            ]
        )
        (Decode.oneOf
            [ field "error" string
            , Decode.succeed ""
            ]
        )


weatherDecoder : Decoder WeatherData
weatherDecoder =
    Decode.map5 WeatherData
        (field "main" (field "temp" float))
        (field "weather" (Decode.index 0 (field "description" string)))
        (field "name" string)
        (field "main" (field "humidity" float))
        (field "wind" (field "speed" float))