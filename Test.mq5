//+------------------------------------------------------------------+
//|                                                   STO Martin.mq5 |
//|                                                        Ryan Chen
//|                                                         Version 1|
//+------------------------------------------------------------------+

#property copyright "CRQ"
#property description "724709897"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>  
#include <Trade\AccountInfo.mqh>
CPositionInfo  m_position;                   // trade position object
CTrade         m_trade;                      // trading object
CSymbolInfo    m_symbol1;                     // symbol info object
CAccountInfo   m_account;                    // account info wrapper


input double               InpLots                       = 0.01;            //首单手数
input double               InpStopLoss                   = 0.0;             // 止损点数
input double               InpTakeProfit                 = 1000.0;             // 止盈点数
input double                OverBuy                      = 0.0 ; //超买开第一单？0为取消
input double                OverSell                     = 0.0 ; //超卖开第一单？0为取消
input double               BuyPositionTarget             = 0.0;            //买单目标盈利
input double               SellPositionTarget            = 0.0;            //卖单目标盈利
input double               LossClose                     = 1000;     //亏到这个金额后关闭订单
input bool                 NAprotect                      = true;  //美盘保护，1000点才加仓
input int                  ExpandTrendProfit             = 3;  //顺势单扩大止盈倍数
input double                 LockLoss                      = 0.5;//最大亏损的百分比锁仓
input double               Tracking                      = 100; // 大于这个点数的两倍，就设置跟踪止损

//--- martingale
input bool                 InpMartin                     = true;           // 是否使用马丁算法
input bool                 LotMartinMultipleMode         =true;            //马丁模式是否倍数加手数
input double                Add_Interval                 =400;             //加仓间隔
input double               InpMartinCoeff                = 1.5;            // 马丁算法系数
input int                  MaxNumberMartin               = 6;           //最大加仓次数


input ulong                m_magic                       = 930873054;      // magic number

//STO判断是否加仓参数
input ENUM_TIMEFRAMES      period=PERIOD_M1;     //    Sto周期
input int                  Kperiod=5;                 // K 线周期 (用于计算的柱数) 
input int                  Dperiod=3;                 // D 线周期(主要平滑周期) 
input int                  slowing=3;                 // 最后平滑周期
input ENUM_MA_METHOD       ma_method=MODE_SMA;        // 平滑类型
input ENUM_STO_PRICE       price_field=STO_LOWHIGH;   // 随机计算方法 

//趋势判断
input bool                 OpenTrendJudge               = true; //开启趋势判断
input int                   MovingPeriod                  = 12;      // Moving Average period
input int                   MovingShift                   = 0;       // Moving Average shift
input ENUM_TIMEFRAMES       Maperiod                        = PERIOD_M15;     //    Ma周期

double   ExtStopLoss=0.0;
double   ExtTakeProfit=0.0;
ulong    m_slippage=10;          // slippage

double   MartinBuyLots                       =0.0;
double   MartinSellLots                      =0.0;
double   AddInterval                         =0;

int      handle_iSto1;
int      MaHandle;

int      BuyPosition                         =0; //买单数量
double   BuyPositionLowestPrice              = 0.0; //买单里面的最低价格
double   BuyPositionLowestLots               = 0.0;  //买单里面的最低价格对应的手数
double   BuyPositionHighestPrice             = 0.0; //买单里面的最高价格
double   BuyPositionHighestLots              = 0.0; //买单里面的最高价格对应的手数
double   BuyPositionLotsTotal                = 0.0;
double   BuyPositionProfitTotal              = 0.0;
double   BuyPositionMinimumLots              = 0.0;
double   BuyPositionMaximumLots              = 0.0;
double   BuyPriceTotal                       = 0.0;
double   BuyMaPrice                          = 0.0;

int      SellPosition                         =0; //买单数量
double   SellPositionLowestPrice             = 0.0;  //卖单里面的最低价格
double   SellPositionLowestLots              = 0.0; //卖单里面的最低价格对应的手数
double   SellPositionHighestPrice            = 0.0; //卖单里面的最高价格
double   SellPositionHighestLots             = 0.0;  //卖单里面的最高价格对应的手数
double   SellPositionLotsTotal               = 0.0;
double   SellPositionProfitTotal             = 0.0;
double   SellPositionMinimumLots             = 0.0;
double   SellPositionMaximumLots             = 0.0;
double   SellPriceTotal                       = 0.0;
double   SellMaPrice                          = 0.0;

bool     MartinBuyReady                      = false;
bool     MartinSellReady                      = false;


int OnInit() //检查输入参数是否合理
  {

   m_symbol1.Name(Symbol()); // sets symbol name

   RefreshRates(m_symbol1);

   string err_text="";
   if(!CheckVolumeValue(m_symbol1,InpLots,err_text))
     {
      Print(__FUNCTION__,", ERROR Lots: ",err_text);
      return(INIT_PARAMETERS_INCORRECT);
     }

//---
   m_trade.SetExpertMagicNumber(m_magic); // 设置Magic.
   m_trade.SetMarginMode();    //设置margin模式
   m_trade.SetTypeFillingBySymbol(m_symbol1.Name());  
   m_trade.SetDeviationInPoints(m_slippage);
   

   ExtStopLoss    = InpStopLoss     * m_symbol1.Point();
   ExtTakeProfit  = InpTakeProfit   * m_symbol1.Point();
   AddInterval    = Add_Interval    * m_symbol1.Point();
   

//--- create handle of the indicator iSto
   handle_iSto1=iStochastic(m_symbol1.Name(),period,Kperiod,Dperiod,slowing,ma_method,price_field);
   MaHandle=iMA(_Symbol,Maperiod,MovingPeriod,MovingShift,MODE_SMA,PRICE_CLOSE);
//--- if the handle is not created 
   if(handle_iSto1==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code 
      PrintFormat(" 加载指标失败 %s/%s, error code %d",
                  m_symbol1.Name(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early 
      return(INIT_FAILED);
     }

   IsPositionExists(m_symbol1);

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {  

     IsPositionExists(m_symbol1);

     if(BuyPosition ==0 || SellPosition == 0) //检查是否有这个EA的订单，如果没有，则执行
     {
  
         int signal=GetSignal(handle_iSto1);
         if(signal!=0)
            if(RefreshRates(m_symbol1))
              {
                                   
                  if(BuyPosition==0&&signal==1) //开第一单多单
                    {
                     double sl=(InpStopLoss==0.0)?0.0:(m_symbol1.Ask()-ExtStopLoss);
                     double tp=(InpTakeProfit==0.0)?0.0:(m_symbol1.Ask()+ExtTakeProfit);
                     
                     OpenBuy(m_symbol1,InpLots,sl,tp,"Fisrt buy");
                          IsPositionExists(m_symbol1);
                     //if(LockLoss !=0.0 && SellPosition== (MaxNumberMartin+1) )
                     //  {
                     // OpenBuy(m_symbol1, MathFloor (SellPositionLotsTotal * LockLoss*100)/100,sl,tp,"LockSell, then Buy");  
                     //  }
                    }
                  if(SellPosition==0&&signal==-1) //开第一单空单
                    {
                     double sl=(InpStopLoss==0)?0.0:(m_symbol1.Bid()+ExtStopLoss);
                     double tp=(InpTakeProfit==0)?0.0:(m_symbol1.Bid()-ExtTakeProfit);
                     OpenSell(m_symbol1,InpLots,sl,tp,"First sell");
                           IsPositionExists(m_symbol1);  
//---

                    }                                             
               
              }

     }
     //加仓？

     IsPositionExists(m_symbol1);
     
      if(BuyPosition !=0 )
      {
            if(RefreshRates(m_symbol1))
              {
               CheckBuyMartin();

               if(MartinBuyReady) 
                 {
                  CalMartinLots();
                  OpenBuy(m_symbol1,MartinBuyLots,0,0,"MartinBuy");

                   IsPositionExists(m_symbol1);
                    
         
                   CheckBuyModify();
                 }
              }
      }
      
      if( SellPosition !=0)
      {
            if(RefreshRates(m_symbol1))
              {
               CheckSellMartin();

               if(MartinSellReady) 
                 {
                  CalMartinLots();
                  OpenSell(m_symbol1,MartinSellLots,0,0,"MartinSell");

                   IsPositionExists(m_symbol1);
                   CheckSellModify();
                 }
              }
      }      
                 

           IsPositionExists(m_symbol1);  
          Trailing();             
         CheckClose();
//   
//---
  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//--
   
  }
  
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
  if(request.comment == "MartinBuy")
  {
  MartinBuyReady = false;


  }
  if(request.comment == "MartinSell")
  {
  MartinSellReady = false;



  }

}
//+------------------------------------------------------------------+



bool CheckVolumeValue(CSymbolInfo &m_symbol,double volume,string &error_description)
  {
//--- minimal allowed volume for trade operations
   double min_volume=m_symbol.LotsMin();
   if(volume<min_volume)
     {
      error_description=StringFormat("低于系统最低允许手数 SYMBOL_VOLUME_MIN=%.2f",min_volume);
      return(false);
     }
//--- maximal allowed volume of trade operations
   double max_volume=m_symbol.LotsMax();
   if(volume>max_volume)
     {
      error_description=StringFormat("超出最大允许手数 SYMBOL_VOLUME_MAX=%.2f",max_volume);
      return(false);
     }
   error_description="Correct volume value";
   return(true);
  }
  
  //+------------------------------------------------------------------+
//| Is position exists                                               |
//+------------------------------------------------------------------+
void IsPositionExists(CSymbolInfo &m_symbol)
  {
   MartinBuyLots                       =0;
   BuyPosition                         =0; //买单数量
   BuyPositionLowestPrice              = 0.0; //买单里面的最低价格
   BuyPositionLowestLots               = 0.0;  //买单里面的最低价格对应的手数
   BuyPositionHighestPrice             = 0.0; //买单里面的最高价格
   BuyPositionHighestLots              = 0.0; //买单里面的最高价格对应的手数
   BuyPositionLotsTotal                = 0.0;
   BuyPositionProfitTotal              = 0.0;
   BuyPositionMinimumLots              = 0.0;
   BuyPositionMaximumLots              = 0.0;
   BuyPriceTotal                       = 0.0;
   BuyMaPrice                          = 0.0;
   
   MartinSellLots                      =0;
   SellPosition                        =0; //买单数量
   SellPositionLowestPrice             = 0.0;  //卖单里面的最低价格
   SellPositionLowestLots              = 0.0; //卖单里面的最低价格对应的手数
   SellPositionHighestPrice            = 0.0; //卖单里面的最高价格
   SellPositionHighestLots             = 0.0;  //卖单里面的最高价格对应的手数
   SellPositionLotsTotal               = 0.0;
   SellPositionProfitTotal             = 0.0;
   SellPositionMinimumLots             = 0.0;
   SellPositionMaximumLots             = 0.0;
   SellPriceTotal                       = 0.0;
   SellMaPrice                          = 0.0;
   
   if ( PositionsTotal()>0)
   {
     for(int i=PositionsTotal()-1;i>=0;i--)
      {   
      if(m_position.SelectByIndex(i)) // 选中订单i
         {
          if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==m_magic && ( m_position.Comment()!="LockSell, then Buy"))
            {
          
             if(m_position.PositionType()==POSITION_TYPE_BUY) //0是POSITION_TYPE_BUY，买单
              { 
               BuyPosition ++;  //买单总量
             
               BuyPositionLotsTotal = BuyPositionLotsTotal + m_position.Volume(); //计算买单总手数
               BuyPositionProfitTotal = BuyPositionProfitTotal + m_position.Profit() + m_position.Commission() + m_position.Swap();//计算买单总盈利金额
               
               BuyPriceTotal = m_position.PriceOpen()*m_position.Volume() + BuyPriceTotal;
               BuyMaPrice = BuyPriceTotal / BuyPositionLotsTotal;
               
               BuyPositionMinimumLots = MathMin(BuyPositionMinimumLots,m_position.Volume());
               BuyPositionMaximumLots = MathMax(BuyPositionMaximumLots,m_position.Volume());

               
               if((BuyPositionLowestPrice>m_position.PriceOpen() ) ||(BuyPositionLowestPrice==0.0))
                    { BuyPositionLowestPrice=m_position.PriceOpen(); //位置最低买单的开单价格
                      BuyPositionLowestLots=m_position.Volume(); //位置最低买单的手数                    
                    }
                    
              
               if((BuyPositionHighestPrice<m_position.PriceOpen())||(BuyPositionHighestPrice==0.0))
                    { BuyPositionHighestPrice=m_position.PriceOpen(); //位置最高买单的开单价格
                      BuyPositionHighestLots=m_position.Volume(); //位置最高买单的手数
                    
                    }            
            
               }
                            
                            
             if(m_position.PositionType()==POSITION_TYPE_SELL) //卖单
               {
                                 
               SellPosition++;//单总量

               SellPositionLotsTotal = SellPositionLotsTotal + m_position.Volume(); //计算卖单总手数
               SellPositionProfitTotal = SellPositionProfitTotal + m_position.Profit() + m_position.Commission() + m_position.Swap();//计算卖单总盈利金额
               
               SellPriceTotal = m_position.PriceOpen()*m_position.Volume() + SellPriceTotal;
               SellMaPrice = SellPriceTotal / SellPositionLotsTotal;               
               
               SellPositionMinimumLots = MathMin (SellPositionMinimumLots, m_position.Volume());
               SellPositionMaximumLots = MathMax (SellPositionMaximumLots,m_position.Volume());

               if((SellPositionLowestPrice>m_position.PriceOpen()) ||(SellPositionLowestPrice==0))
                    { 
                    
                      SellPositionLowestPrice=m_position.PriceOpen(); //位置最低卖单的开单价格
                      SellPositionLowestLots=m_position.Volume(); //位置最低卖单的手数
   
                    }

               if((SellPositionHighestPrice<m_position.PriceOpen())||(SellPositionHighestPrice == 0))
                    { SellPositionHighestPrice=m_position.PriceOpen(); //位置最高卖单的开单价格
                      SellPositionHighestLots=m_position.Volume(); //位置最高卖单的手数                   
                    }  
 
                }   // 
            }//magic
         
         } //select
   
      } //for
 //     return(true);
   }//

  }

//+------------------------------------------------------------------+
//| Check the fist order signal                                               |
//+------------------------------------------------------------------+   
int GetSignal(int &handle)
{
   int vSignal=0;
       
   int trend =  CheckTrend();
       
   double Stoch_Main_0 =iStochasticGet(handle,MAIN_LINE,0);
   double Stoch_Main_1 =iStochasticGet(handle,MAIN_LINE,1);
   double Stoch_Sign_0 =iStochasticGet(handle,SIGNAL_LINE,0);
   double Stoch_Sign_1 =iStochasticGet(handle,SIGNAL_LINE,1);
   
   if(OpenTrendJudge == true)
   {
      if(trend == 1)
        {

            if( (OverSell!=0) && (Stoch_Main_0<OverSell) && Stoch_Main_1<Stoch_Sign_1 && Stoch_Main_0>Stoch_Sign_0)
            vSignal=+1;//up  超卖 金叉 ,所以要买进，信号+1
            //else
            //if( (OverBuy!=0) && (Stoch_Main_0>OverBuy) && Stoch_Main_1>Stoch_Sign_1 && Stoch_Main_0<Stoch_Sign_0)
            //vSignal=-1;//down  超买  死叉
          
    
           
            if(OverSell==0 && Stoch_Main_1<Stoch_Sign_1 && Stoch_Main_0>Stoch_Sign_0)
            vSignal=+1;//up  超卖 金叉
            //else
            //if(Stoch_Main_1>Stoch_Sign_1 && Stoch_Main_0<Stoch_Sign_0)
            //vSignal=-1;//down  超买  死叉
           
      }
      
    if( trend == -1)
      {
            //if( (OverSell!=0) && (Stoch_Main_0<OverSell) && Stoch_Main_1<Stoch_Sign_1 && Stoch_Main_0>Stoch_Sign_0)
            //vSignal=+1;//up  超卖 金叉 ,所以要买进，信号+1
            //else
            if( (OverBuy!=0) && (Stoch_Main_0>OverBuy) && Stoch_Main_1>Stoch_Sign_1 && Stoch_Main_0<Stoch_Sign_0)
            vSignal=-1;//down  超买  死叉
          
    
           
            //if(OverSell==0 && Stoch_Main_1<Stoch_Sign_1 && Stoch_Main_0>Stoch_Sign_0)
            //vSignal=+1;//up  超卖 金叉
            //else
            if(OverBuy == 0 && Stoch_Main_1>Stoch_Sign_1 && Stoch_Main_0<Stoch_Sign_0)
            vSignal=-1;//down  超买  死叉      
    
      }       
  
   } 

   if(OpenTrendJudge == false)
   {

            if( (OverSell!=0) && (Stoch_Main_0<OverSell) && Stoch_Main_1<Stoch_Sign_1 && Stoch_Main_0>Stoch_Sign_0)
            vSignal=+1;//up  超卖 金叉 ,所以要买进，信号+1

            if( (OverBuy!=0) && (Stoch_Main_0>OverBuy) && Stoch_Main_1>Stoch_Sign_1 && Stoch_Main_0<Stoch_Sign_0)
            vSignal=-1;//down  超买  死叉
          
    
           
            if(OverSell==0 && Stoch_Main_1<Stoch_Sign_1 && Stoch_Main_0>Stoch_Sign_0)
            vSignal=+1;//up  超卖 金叉
            //else
            if(OverBuy == 0 && Stoch_Main_1>Stoch_Sign_1 && Stoch_Main_0<Stoch_Sign_0)
            vSignal=-1;//down  超买  死叉
           
  
   } 

   return(vSignal);
 }
  
  double iStochasticGet(int handle_iStochastic,const int buffer,const int index)
  {
   double Stochastic[1];
//--- reset error code 
   ResetLastError();
//--- fill a part of the iStochasticBuffer array with values from the indicator buffer that has 0 index 
   if(CopyBuffer(handle_iStochastic,buffer,index,1,Stochastic)<0)
     {
      //--- if the copying fails, tell the error code 
      PrintFormat("Failed to copy data from the iStochastic indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated 
      return(0.0);
     }
   return(Stochastic[0]);
}
  
//+------------------------------------------------------------------+
//| Check Martin Signal                                                |
//+------------------------------------------------------------------+  

void CheckBuyMartin( )
{    
      double Interval;
      
      MqlDateTime ProtectTime;
      TimeCurrent (ProtectTime);
      
       Interval = (NAprotect && (ProtectTime.hour>15 && ProtectTime.hour<18)) ? (10000* m_symbol1.Point() ) : AddInterval;

           
      
      
     if(BuyPosition <= MaxNumberMartin)
       {
      MartinBuyReady = ((BuyPositionLowestPrice-m_symbol1.Ask())>=Interval)? true : false;       
       }     
       
}

void CheckSellMartin()
{

      double Interval;
      
      MqlDateTime ProtectTime;
      TimeCurrent (ProtectTime);
       Interval = (NAprotect && (ProtectTime.hour>15 && ProtectTime.hour<18)) ? (10000* m_symbol1.Point() ) : AddInterval;  
           
     if(SellPosition <= MaxNumberMartin)
       {
      MartinSellReady = ((m_symbol1.Bid()-SellPositionHighestPrice)>=Interval) ? true : false;       
       }
       
   
}   


//+------------------------------------------------------------------+
//| Calculate Martin mode lots                                                |
//+------------------------------------------------------------------+ 
void CalMartinLots()
{
   if(LotMartinMultipleMode)
   {
   
   MartinBuyLots = BuyPositionLowestLots * InpMartinCoeff;
   MartinSellLots = SellPositionHighestLots * InpMartinCoeff;
  // Print(MartinBuyLots);
   }

}
  
//+------------------------------------------------------------------+
//| Open Buy position                                                |
//+------------------------------------------------------------------+
void OpenBuy(CSymbolInfo &m_symbol,double lots, double sl,double tp,string comment)
  {
   sl=m_symbol.NormalizePrice(sl);
   tp=m_symbol.NormalizePrice(tp);
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   double check_volume_lot=m_trade.CheckVolume(m_symbol.Name(),lots,m_symbol.Ask(),ORDER_TYPE_BUY);

   if(check_volume_lot!=0.0)
      if(check_volume_lot>=m_symbol.LotsMin())
        {
         if(m_trade.Buy(lots,m_symbol.Name(),m_symbol.Ask(),sl,tp, comment))
           {
            if(m_trade.ResultDeal()==0)
              {
               Print("Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
              }
            else
              {
             //       MartinBuyReady = false;

               Print("Buy -> true. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
              }
           }
         else
           {
            Print("Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
           }
        }
//---
  }
//+------------------------------------------------------------------+
//| Open Sell position                                               |
//+------------------------------------------------------------------+
void OpenSell(CSymbolInfo &m_symbol,double lots, double sl,double tp,string comment)
  {
//   sl=m_symbol.NormalizePrice(sl);
 //  tp=m_symbol.NormalizePrice(tp);
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   double check_volume_lot=m_trade.CheckVolume(m_symbol.Name(),lots,m_symbol.Bid(),ORDER_TYPE_SELL);

   if(check_volume_lot!=0.0)
      if(check_volume_lot>=m_symbol.LotsMin())
        {
         if(m_trade.Sell(lots,m_symbol.Name(),m_symbol.Bid(),sl,tp,comment))
           {
            if(m_trade.ResultDeal()==0)
              {
               Print("Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
              }
            else
              {
                   //                 MartinSellReady = false;
               Print("Sell -> true. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
              }
           }
         else
           {
            Print("Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
           }
        }
//---
  }

//+------------------------------------------------------------------+
  //| Check the position if it is ready to close                                 |
//+------------------------------------------------------------------+ 
void CheckClose()
{
   double BuyTP;
   double SellTP;
        
   SellTP = (BuyPosition > SellPosition )? (SellPositionTarget * ExpandTrendProfit): SellPositionTarget;
 
   BuyTP =   (SellPosition > BuyPosition) ? (BuyPositionTarget * ExpandTrendProfit): BuyPositionTarget;

   for(int i=PositionsTotal()-1;i>=0;i--) // returns the number of current positions
     {
      if(m_position.SelectByIndex(i))     // selects the position by index for further access to its properties
       {
         if((m_position.Symbol()==m_symbol1.Name() ) && (m_position.Magic()==m_magic))
            {
            
            if ( BuyPositionTarget!=0 && (BuyPositionProfitTotal>BuyTP) && (m_position.PositionType()==POSITION_TYPE_BUY))
               {
                m_trade.PositionClose(m_position.Ticket()); // close a position by the specified symbol
               }
               
            if (SellPositionTarget !=0 &&(SellPositionProfitTotal>SellTP) && (m_position.PositionType()==POSITION_TYPE_SELL))
               {
                m_trade.PositionClose(m_position.Ticket()); // close a position by the specified symbol      
               } 
               
               
            if (LossClose!=0 && BuyPositionProfitTotal<= (-LossClose)  && (m_position.PositionType()==POSITION_TYPE_BUY))
              {
                m_trade.PositionClose(m_position.Ticket()); // close a position by the specified symbol
              } 
              
            if (LossClose!=0 && SellPositionProfitTotal<=(-LossClose)  && (m_position.PositionType()==POSITION_TYPE_SELL))
              {
                m_trade.PositionClose(m_position.Ticket()); // close a position by the specified symbol
              } 
                
           }         
       }
     }
}  


//+------------------------------------------------------------------+
  //| Refreshes the symbol quotes data                                 |
//+------------------------------------------------------------------+
bool RefreshRates(CSymbolInfo &m_symbol) // 让MqlTick结构体的成员的值更新
  {
//--- refresh rates
   if(!m_symbol.RefreshRates())
     {
      Print("RefreshRates error");
      return(false);
     }
//--- protection against the return value of "zero"
   if(m_symbol.Ask()==0 || m_symbol.Bid()==0)
      return(false);
//---
   return(true);
  }
//+------------------------------------------------------------------+
//CheckModify
//+------------------------------------------------------------------+
void CheckBuyModify ()

{
 double SL;
 double TP;
    

  
   if(InpStopLoss!=0 || InpTakeProfit!=0)
     {
        SL = (InpStopLoss!=0) ? (BuyMaPrice - ExtStopLoss) : 0.0;
        TP = (InpTakeProfit!=0) ? (BuyMaPrice + ExtTakeProfit) : 0.0;
        
        TP = (SellPosition > BuyPosition )? (BuyMaPrice + ExtTakeProfit*2) : TP;
   for(int i=PositionsTotal()-1;i>=0;i--) // returns the number of current positions
     {
      if(m_position.SelectByIndex(i))     // selects the position by index for further access to its properties
       {
         if((m_position.Symbol()==m_symbol1.Name() ) && (m_position.Magic()==m_magic))
            {
            if (m_position.PositionType()==POSITION_TYPE_BUY)
               {

                m_trade.PositionModify(m_position.Ticket(),SL, TP); // close a position by the specified symbol

               }
            }         
       }
     }
    }

}

void CheckSellModify ()

{
 double SL;
 double TP;
  
     if(InpStopLoss!=0 || InpTakeProfit!=0)
     {
        SL = (InpStopLoss!=0) ? (SellMaPrice + ExtStopLoss) : 0.0;
        TP = (InpTakeProfit!=0) ? (SellMaPrice - ExtTakeProfit) : 0.0;
        TP = (BuyPosition > SellPosition )? (SellMaPrice - ExtTakeProfit*2) : TP;
        
     for(int i=PositionsTotal()-1;i>=0;i--) // returns the number of current positions
     {
      if(m_position.SelectByIndex(i))     // selects the position by index for further access to its properties
       {
         if((m_position.Symbol()==m_symbol1.Name() ) && (m_position.Magic()==m_magic))
            {
               
            if (m_position.PositionType()==POSITION_TYPE_SELL)
               {

                m_trade.PositionModify(m_position.Ticket(),SL, TP); // close a position by the specified symbol
 
               }   
            }         
       }
     }       
     }
  


}

int CheckTrend()
{
   double ma[];
   int Trend = 0;
   CopyBuffer(MaHandle,0,0,1,ma);
   if(m_symbol1.AskHigh()<ma[0])
     {
         Trend = -1; //空头
     }
   
   if(m_symbol1.BidHigh()>ma[0])
     {
         Trend = 1; //多头
     }
    return Trend;
}

void  Trailing()
{
   double SLBuy;
   double SLSell;
   double OriginalSLbuy;
   double OriginalSLsell;
   if((m_symbol1.Bid()-BuyMaPrice) > Tracking * m_symbol1.Point()*2)
     {
      if(Tracking!=0)
        {
           SLBuy = BuyMaPrice +  Tracking * m_symbol1.Point();
           //if(m_symbol1.Digits()==3)
           //  {
           //   SLBuy = MathFloor(SLBuy*1000) / 1000;
           //  }
           //if(m_symbol1.Digits()==5)
           //  {
           //   SLBuy = MathFloor(SLBuy*100000)/100000;
           //  }
      for(int i=PositionsTotal()-1;i>=0;i--) // returns the number of current positions
        {
         if(m_position.SelectByIndex(i))     // selects the position by index for further access to its properties
          {
            if((m_position.Symbol()==m_symbol1.Name() ) && (m_position.Magic()==m_magic))
               {
               if (m_position.PositionType()==POSITION_TYPE_BUY)
                  {
                       OriginalSLbuy = m_position.StopLoss();
                       //if(m_symbol1.Digits()==3)
                       //  {
                       //   OriginalSLbuy= MathFloor(m_position.StopLoss()*1000) / 1000;
                       //  }
                       //if(m_symbol1.Digits()==5)
                       //  {
                       //   OriginalSLbuy = MathFloor(m_position.StopLoss()*100000)/100000;
                       //  }
                  if( (OriginalSLbuy!=0 && (SLBuy - OriginalSLbuy )>=Tracking * m_symbol1.Point()/2 ) || (OriginalSLbuy == 0))
                    {

                   m_trade.PositionModify(m_position.Ticket(),SLBuy, m_position.TakeProfit()); // close a position by the specified symbol                     
                    }

   
                  }
               }         
          }
        }
       }       
     }
     
   if((SellMaPrice - m_symbol1.Ask()) > Tracking * m_symbol1.Point()*2)
     {
      if(Tracking!=0)
        {
           SLSell = SellMaPrice -  Tracking * m_symbol1.Point();


      for(int i=PositionsTotal()-1;i>=0;i--) // returns the number of current positions
        {
         if(m_position.SelectByIndex(i))     // selects the position by index for further access to its properties
          {
            if((m_position.Symbol()==m_symbol1.Name() ) && (m_position.Magic()==m_magic))
               {
               if (m_position.PositionType()==POSITION_TYPE_SELL)
                  {     
                         OriginalSLsell=m_position.StopLoss();
                                                        
                  if( ( OriginalSLsell!=0 && (SLSell - OriginalSLsell) >= Tracking * m_symbol1.Point()/2 ) || (OriginalSLsell==0))
                    {    

                    m_trade.PositionModify(m_position.Ticket(),SLSell, m_position.TakeProfit()); // close a position by the specified symbol                    
                    }

   
                  }
               }         
          }
        }
       }       
     }

}