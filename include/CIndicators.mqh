
class CIndicator
{
protected:
    int m_handle;
    string m_symbol;
    ENUM_TIMEFRAMES m_timeFrame;

    virtual int CreateHandle() = 0;
    virtual void SetupBuffers() {}

public:
    CIndicator(string symbol, ENUM_TIMEFRAMES timeFrame)
        : m_handle(INVALID_HANDLE), m_symbol(symbol), m_timeFrame(timeFrame) {}

    virtual ~CIndicator()
    {
        if (m_handle != INVALID_HANDLE)
            IndicatorRelease(m_handle);
    }

    bool Initialize()
    {
        m_handle = CreateHandle();
        if (m_handle != INVALID_HANDLE)
        {
            SetupBuffers();
            return true;
        }
        Print("Failed to create handle for ", GetName());
        return false;
    }

    virtual string GetName() const = 0;
    int GetHandle() const { return m_handle; }

    double GetValue(int index, int bufferIndex = 0, int count = 1)
    {
        double buffer[];
        ArraySetAsSeries(buffer, true);
        if (CopyBuffer(m_handle, bufferIndex, index, count, buffer) > 0)
            return buffer[0];
        return 0.0;
    }

    bool GetValues(int bufferIndex, int start, int count, double &result[])
    {
        ArraySetAsSeries(result, true);
        return CopyBuffer(m_handle, bufferIndex, start, count, result) == count;
    }
};

//+------------------------------------------------------------------+
//|                                                          RSI     |
//+------------------------------------------------------------------+
class CRSI : public CIndicator
{
protected:
    int m_period;
    ENUM_APPLIED_PRICE m_applied;

    int CreateHandle()
    {
        return iRSI(m_symbol, m_timeFrame, m_period, m_applied);
    }

public:
    CRSI(string symbol, ENUM_TIMEFRAMES tf, int period,
         ENUM_APPLIED_PRICE applied = PRICE_CLOSE)
        : CIndicator(symbol, tf), m_period(period), m_applied(applied) {}

    string GetName() const { return "RSI"; }
};

//+------------------------------------------------------------------+
//|                                                     Bollinger    |
//+------------------------------------------------------------------+
class CBollinger : public CIndicator
{
    int m_period;
    double m_deviation;
    int m_shift;

protected:
    int CreateHandle()
    {
        return iBands(m_symbol, m_timeFrame, m_period,
                      m_shift, m_deviation, PRICE_CLOSE);
    }

public:
    CBollinger(string symbol, ENUM_TIMEFRAMES tf, int period,
               double dev, int shift = 0)
        : CIndicator(symbol, tf), m_period(period),
          m_deviation(dev), m_shift(shift) {}

    string GetName() const { return "Bollinger"; }

    double Upper(int index) { return GetValue(0, index); }
    double Middle(int index) { return GetValue(1, index); }
    double Lower(int index) { return GetValue(2, index); }
};

//+------------------------------------------------------------------+
//|                                                           MA     |
//+------------------------------------------------------------------+
class CMA : public CIndicator
{
    int m_period;
    ENUM_MA_METHOD m_method;
    int m_shift;
    ENUM_APPLIED_PRICE m_applied;

protected:
    int CreateHandle()
    {
        return iMA(m_symbol, m_timeFrame, m_period,
                   m_shift, m_method, m_applied);
    }

public:
    CMA(string symbol, ENUM_TIMEFRAMES tf, int period,
        ENUM_MA_METHOD method, int shift = 0,
        ENUM_APPLIED_PRICE applied = PRICE_CLOSE)
        : CIndicator(symbol, tf), m_period(period),
          m_method(method), m_shift(shift), m_applied(applied) {}

    string GetName() const { return "MA"; }
};

//+------------------------------------------------------------------+
//|                                                     Heiken Ashi  |
//+------------------------------------------------------------------+
class CHeikenAshi : public CIndicator
{
    double m_open[], m_high[], m_low[], m_close[];

protected:
    int CreateHandle()
    {
        return iCustom(m_symbol, m_timeFrame, "Examples\\Heiken_Ashi");
    }

    void SetupBuffers()
    {
        ArraySetAsSeries(m_open, true);
        ArraySetAsSeries(m_high, true);
        ArraySetAsSeries(m_low, true);
        ArraySetAsSeries(m_close, true);
    }

public:
    CHeikenAshi(string symbol, ENUM_TIMEFRAMES tf)
        : CIndicator(symbol, tf) {}

    string GetName() const { return "HeikenAshi"; }

    void Refresh(int count = 100)
    {
        CopyBuffer(m_handle, 0, 0, count, m_open);
        CopyBuffer(m_handle, 1, 0, count, m_high);
        CopyBuffer(m_handle, 2, 0, count, m_low);
        CopyBuffer(m_handle, 3, 0, count, m_close);
    }

    double Open(int index) const { return m_open[index]; }
    double High(int index) const { return m_high[index]; }
    double Low(int index) const { return m_low[index]; }
    double Close(int index) const { return m_close[index]; }
};
//+------------------------------------------------------------------+
//|                                                          ATR     |
//+------------------------------------------------------------------+
class CATR : public CIndicator
{
    int m_period;

protected:
    int CreateHandle()
    {
        return iATR(m_symbol, m_timeFrame, m_period);
    }

public:
    CATR(string symbol, ENUM_TIMEFRAMES tf, int period)
        : CIndicator(symbol, tf), m_period(period) {}

    string GetName() const { return "ATR"; }
};

//+------------------------------------------------------------------+
//|                                                          MFI     |
//+------------------------------------------------------------------+
class CMFI : public CIndicator
{
    int m_period;
    ENUM_APPLIED_VOLUME m_volumeType;

protected:
    int CreateHandle()
    {
        return iMFI(m_symbol, m_timeFrame, m_period, m_volumeType);
    }

public:
    CMFI(string symbol, ENUM_TIMEFRAMES tf, int period,
         ENUM_APPLIED_VOLUME volumeType = VOLUME_TICK)
        : CIndicator(symbol, tf), m_period(period), m_volumeType(volumeType) {}

    string GetName() const { return "MFI"; }
};

//+------------------------------------------------------------------+
//|                                                      MACD        |
//+------------------------------------------------------------------+
class CMACD : public CIndicator
{
    int m_fast;
    int m_slow;
    int m_signal;

protected:
    int CreateHandle()
    {
        return iMACD(m_symbol, m_timeFrame, m_fast, m_slow, m_signal, PRICE_CLOSE);
    }

public:
    CMACD(string symbol, ENUM_TIMEFRAMES tf, int fast, int slow, int signal)
        : CIndicator(symbol, tf), m_fast(fast), m_slow(slow), m_signal(signal) {}

    string GetName() const { return "MACD"; }

    double Main(int index) { return GetValue(0, index); }
    double Signal(int index) { return GetValue(1, index); }
    double Histogram(int index) { return Main(index) - Signal(index); }
};

//+------------------------------------------------------------------+
//|                                                     Donchian     |
//+------------------------------------------------------------------+
class CDonchian : public CIndicator
{
    int m_period;

protected:
    int CreateHandle()
    {
        return iCustom(m_symbol, m_timeFrame, "Wait_Indicators\\donchian_channel", m_period);
    }

public:
    CDonchian(string symbol, ENUM_TIMEFRAMES tf, int period)
        : CIndicator(symbol, tf), m_period(period) {}

    string GetName() const { return "Donchian"; }

    double Upper(int index) { return GetValue(0, index); }
    double Lower(int index) { return GetValue(1, index); }
};

//+------------------------------------------------------------------+
//|                                                      ALMA        |
//+------------------------------------------------------------------+
class CALMA : public CIndicator
{
    int m_period;
    double m_sigma;
    double m_offset;

protected:
    int CreateHandle()
    {
        return iCustom(m_symbol, m_timeFrame, "Wait_Indicators\\alma_v2",
                       m_period, m_sigma, m_offset, PRICE_CLOSE);
    }

public:
    CALMA(string symbol, ENUM_TIMEFRAMES tf, int period,
          double sigma = 6.0, double offset = 0.85)
        : CIndicator(symbol, tf), m_period(period),
          m_sigma(sigma), m_offset(offset) {}

    string GetName() const { return "ALMA"; }
};

//+------------------------------------------------------------------+
//|                                                      KAMA        |
//+------------------------------------------------------------------+
class CKAMA : public CIndicator
{
    int m_period;
    int m_fast;
    int m_slow;

protected:
    int CreateHandle()
    {
        return iAMA(m_symbol, m_timeFrame, m_period, m_fast, m_slow, 0, PRICE_CLOSE);
    }

public:
    CKAMA(string symbol, ENUM_TIMEFRAMES tf, int period,
          int fast = 2, int slow = 30)
        : CIndicator(symbol, tf), m_period(period),
          m_fast(fast), m_slow(slow) {}

    string GetName() const { return "KAMA"; }
};

//+------------------------------------------------------------------+
//|                                                      Pivot       |
//+------------------------------------------------------------------+
class CPivot : public CIndicator
{
    ENUM_TIMEFRAMES m_baseTF;
    int m_mode;

protected:
    int CreateHandle()
    {
        return iCustom(m_symbol, m_timeFrame, "Wait_Indicators\\All Pivot Points",
                       m_baseTF, m_mode);
    }

public:
    CPivot(string symbol, ENUM_TIMEFRAMES tf,
           ENUM_TIMEFRAMES baseTF = PERIOD_D1, int mode = 0)
        : CIndicator(symbol, tf), m_baseTF(baseTF), m_mode(mode) {}

    string GetName() const { return "Pivot"; }

    double R3(int index) { return GetValue(0, index); }
    double R2(int index) { return GetValue(1, index); }
    double R1(int index) { return GetValue(2, index); }
    double P(int index) { return GetValue(3, index); }
    double S1(int index) { return GetValue(4, index); }
    double S2(int index) { return GetValue(5, index); }
    double S3(int index) { return GetValue(6, index); }
};
//+------------------------------------------------------------------+
//|                                                      Usage       |
//+------------------------------------------------------------------+
/*
void OnStart()
{
    CRSI rsi(_Symbol, PERIOD_H1, 14, PRICE_CLOSE);
    if(!rsi.Initialize()) return;

    Print("Current RSI: ", rsi.GetValue(0, 0));

    CBollinger boll(_Symbol, PERIOD_H1, 20, 2.0);
    if(!boll.Initialize()) return;

    Print("Upper Band: ", boll.Upper(0));

    CHeikenAshi ha(_Symbol, PERIOD_H1);
    if(!ha.Initialize()) return;

    ha.Refresh();
    Print("HA Close: ", ha.Close(0));
}
*/
//+------------------------------------------------------------------+