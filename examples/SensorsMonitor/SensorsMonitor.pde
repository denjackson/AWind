/*
  AWind.h - Arduino window library support for Color TFT LCD Boards
  Copyright (C)2014 Andrei Degtiarev. All right reserved
  
  You can find the latest version of the library at 
  https://github.com/AndreiDegtiarev/AWind

  This library is free software; you can redistribute it and/or
  modify it under the terms of the CC BY-NC-SA 3.0 license.
  Please see the included documents for further information.

  Commercial use of this library requires you to buy a license that
  will allow commercial use. This includes using the library,
  modified or not, as a tool to sell products.

  The license applies to all part of the library including the 
  examples and tools supplied with the library.
*/
// DEMO_SENSORS allows run of this sketch in DEMO mode without real sensor connections 
#define DEMO_SENSORS
//#define DEBUG_AWIND //!<remove comments if name of window is need to known during runtime. Be carrefull about SRAM

#ifndef DEMO_SENSORS
#include <OneWire.h>
#include <SPI.h>
#include <RF24.h>
#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BMP085_U.h>
#include <DHT.h>
#endif

#include <UTFT.h>
#include <UTouch.h>

#include "AHelper.h"
#include "ISensor.h"
#include "DS18B20Sensor.h"
#include "DHTTemperatureSensor.h"
#include "DHTHumiditySensor.h"
#include "BMP085Sensor.h"

#include "SensorManager.h"
#include "MeasurementNode.h"

#include "WindowsManager.h"
#include "SensorWindow.h"
#include "MeasurementNode.h"

// Setup TFT display + touch (see UTFT and UTouch library documentation)
UTFT    myGLCD(ITDB32S,39,41,43,45);
UTouch  myTouch( 49, 51, 53, 50, 52);

//pin on Arduino where temperature sensor is connected (in demo is meaningless)
int temperature_port=10;

//list where all sensors are collected
LinkedList<SensorManager> sensors;
//manager which controls the measurement process
MeasurementNode measurementNode(sensors);

//manager which is responsible for window updating process
WindowsManager<ViewModusWindow> windowsManager(&myGLCD,&myTouch);

void setup()
{
	//setup log (out is wrap about Serial class)
	out.begin(57600);
	out<<F("Setup")<<endl;

	//this example runs on the limit of SRAM. Here is initial check
	AHelper::LogFreeRam();

	//initialize display
	myGLCD.InitLCD();
	myGLCD.clrScr();
	//my speciality I have connected LED-A display pin to the pin 47 on Arduino board. Comment next two lines if the example from UTFT library runs without any problems 
	pinMode(47,OUTPUT);
	digitalWrite(47,HIGH);
	//initialize touch
	myTouch.InitTouch();
	myTouch.setPrecision(PREC_MEDIUM);

	//initialize window manager
	windowsManager.Initialize();

	//sensors
	DHTTemperatureSensor *inTempr=new DHTTemperatureSensor(temperature_port+2);
	DHTHumiditySensor *inHumidity=new DHTHumiditySensor(inTempr);
	DHTTemperatureSensor *alkovenTempr=new DHTTemperatureSensor(temperature_port-2);
	DHTHumiditySensor *alkovenHumidity=new DHTHumiditySensor(alkovenTempr);
	BMP085Sensor *pressure=new BMP085Sensor();
	DS18B20Sensor *fridgeTempr=new DS18B20Sensor(temperature_port,1);
	DS18B20Sensor *outTempr=new DS18B20Sensor(temperature_port,2);
	//sensor managers. Manager defines measurement limits and measurement delays
	sensors.Add(new SensorManager(inTempr,15,40,1000*10)); //0
	sensors.Add(new SensorManager(inHumidity,0,80,1000*10)); //1
	sensors.Add(new SensorManager(alkovenTempr,15,40,1000*10)); //2
	sensors.Add(new SensorManager(alkovenHumidity,0,80,1000*10));//3
	sensors.Add(new SensorManager(pressure,700,1300,1000*10));//4
	sensors.Add(new SensorManager(fridgeTempr,-5,16,1000*10));//5
	sensors.Add(new SensorManager(outTempr,-30,40,1000*10));//6

	//sensor windows
	int second_column = SensorWindow::BigWindowWidth+SensorWindow::Margin/2;
	int second_row=SensorWindow::BigWindowHeight+SensorWindow::Margin/2;
	ViewModusWindow *modusWindow=windowsManager.MainWnd();
	modusWindow->AddChild(new SensorWindow(F("In Temp"),sensors[0],0,0));
	modusWindow->AddChild(new SensorWindow(F("In Humid"),sensors[1],second_column,0));
	modusWindow->AddChild(new SensorWindow(F("Out"),sensors[6],0,second_row));
	int third_column = second_column + SensorWindow::SmallWindowWidth+SensorWindow::Margin/2;
	int third_row = second_row + SensorWindow::SmallWindowHeight+SensorWindow::Margin/2;
	modusWindow->AddChild(new SensorWindow(F("Pressure"),sensors[4],second_column,second_row,SensorWindow::Small));
	modusWindow->AddChild(new SensorWindow(F("Fridge"),sensors[5],third_column,second_row,SensorWindow::Small));
	modusWindow->AddChild(new SensorWindow(F("Alk Temp"),sensors[2],second_column,third_row,SensorWindow::Small));
	modusWindow->AddChild(new SensorWindow(F("Alk Humid"),sensors[3],third_column,third_row,SensorWindow::Small));
	modusWindow->Initialize();
	//in order to avoid pause in the touch interactions, windows manager is defined as critical process
	measurementNode.SetCriticalProcess(&windowsManager);

	delay(1000); 
	//Checks how much SRAM is left. If it is less than 300, the example will not work stably. The usage of SRAM can be reduced by changing buf_size variable in SensorManager.h (AFrame)
	AHelper::LogFreeRam();

	out<<F("End setup")<<endl;

}

void loop()
{
	//measure (if necessary -see delay parameter in sensor manager)
	if(measurementNode.Measure())
	{
		//following if is only for debugging purposes
		if(measurementNode.IsChanged())
		{
			measurementNode.LogResults();
		}

	}
	//give window manager an opportunity to update display
	windowsManager.loop();
}

