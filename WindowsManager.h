/*
  AWind.h - Arduino window library support for Color TFT LCD Boards
  Copyright (C)2014 Andrei Degtiarev. All right reserved
  

  You can always find the latest version of the library at 
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
#pragma once

#include "Window.h"
#include "KeyboardWindow.h"
#include "MainWindow.h"
#include "ICriticalProcess.h"

UTFT *globalLcd;
template <class T=MainWindow> class WindowsManager :  public ICriticalProcess, public ILoopProcess
{
	DC _dc;
	T *_mainWindow;
	UTouch  *_touch;
public:
	WindowsManager(UTFT *lcd,UTouch *touch=NULL):_dc(lcd),_touch(touch)
	{
		globalLcd=lcd;
	}
	void Initialize()
	{
		_mainWindow=new T(_dc.DeviceWidth(),_dc.DeviceHeight());
		_mainWindow->Invalidate();
		_mainWindow->SetLoopProcess(this);
	}
	Window *HitTest(int x,int y)
	{
		if(MainWnd()->ModalWnd()!=NULL)
			return HitTest(MainWnd()->ModalWnd(),x,y);
		else
			return HitTest(MainWnd(),x,y);
	}
	Window *HitTest(Window *window,int x,int y)
	{
		if(window->IsVisible()
			&&x>=window->Left() && x<=window->Left()+window->Width()
			&&y>=window->Top() && y<=window->Top()+window->Height())
		{
			for(int i=0;i<window->Children().Count();i++)
			{
				Window * retWnd=HitTest(window->Children()[i],x-window->Left(),y-window->Top());
				if(retWnd!=NULL)
					return retWnd;
			}
			return window;
		}
		return NULL;
	}
	void loop()
	{
		if(MainWnd()->ModalWnd() == NULL)
			redraw(MainWnd(),false);
		if(MainWnd()->ModalWnd() != NULL)
			redraw(MainWnd()->ModalWnd(),MainWnd()->ModalWnd()->IsDirty());
	}
	T *MainWnd()
	{
		return _mainWindow;
	}
	DC *GetDC()
	{
		return &_dc;
	}
	void Idle()
	{
		if(_touch!=NULL)
			loopTouch();
	}
protected:
	void redraw(Window *window,bool isForceRedraw)
	{
		Idle();
		if(window == MainWnd()->ModalWnd() && window->IsDirty() && isForceRedraw == false) // Modal window is updated as last one by use of isForceRedraw flag
			return;
		bool needRedraw=isForceRedraw || window->IsDirty();
		if(needRedraw)
			window->Redraw(&_dc);
		for(int i=0;i<window->Children().Count();i++)
		{
			Window *child=window->Children()[i];
			if(child->IsVisible())
				redraw(child,needRedraw);
		}

	}
	void loopTouch()
	{
		//out<<F("Check touch")<<endl;
		if (_touch->dataAvailable())
		{
			_touch->read();
			int x=_touch->getX();
			int y=_touch->getY();
			//out<<F("Touch begins x:")<<x<<F(" y:")<<y<<endl;
			if(x>0 && y>0)
			{
				Window *window=HitTest(x,y);
				Window *touchWnd=NULL;
				if(window!=NULL)
				{
					Window *crWindow=window;
					//out<<F("Searching touch window: ")<<endl;
					while(crWindow!=NULL && (!crWindow->IsAwaitTouch()))
					{
						//out<<crWindow->Name()<<endl;
						crWindow=crWindow->Parent();	
					}
					if(crWindow != NULL)
					{
						//out<<F("Touch found")<<endl;
						touchWnd=crWindow;
						touchWnd->OnTouching(GetDC());
					}
				}
				if(touchWnd!=NULL)
				{
					while (_touch->dataAvailable())
					{
						_touch->read();
					}
					//out<<F("Touch: ")<<touchWnd->Name()<<endl;
					{
						Window *crWindow=touchWnd;
						while(crWindow!=NULL && ((crWindow->IsAwaitTouch()) && !(crWindow)->OnTouch(x,y))||!crWindow->IsAwaitTouch())
						{
							crWindow=crWindow->Parent();	
							//out<<F("Touch while")<<endl;
						}
						//out<<F("Touch invalidate")<<endl;
						touchWnd->Invalidate();
					}
				}
				//out<<F("Touch finish")<<endl;
			}
		}
	}
};