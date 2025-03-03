

void OnStart()
{
       // int symbol = Symbol();
       double bance = 10000;
       string symbol = 
       double entryPrice = 150.634;
       double stopLossPrice = 149.426;
       double atr = 0.604;
       double maxRisk = 0.02;
       double lot = (bance * maxRisk) / (atr * 2);

       double slMoney = 0;
       // 亏损的钱
       slMoney = bance * maxRisk;
       // 几位小数
       int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);

       double slDistance = NormalizeDouble(MathAbs(et - sl), digits) / _Point;

       if (slDistance <= 0)
       {
              Print("Stop loss distance is zero or negative.");
              return 0;
       }

       double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_POINT);

       // 风控 / 止损 / 点值 迷你手数需要除以100
       double lot = NormalizeDouble(slMoney / slDistance / tickValue / 100, 2);

       double lotstep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
       lot = MathRound(lot / lotstep) * lotstep;

       if (lot < SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN))
              lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
       else if (lot >= SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX))
              lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);

       Print("✔️[Test.mq5:13]: lot: ", lot);
}
