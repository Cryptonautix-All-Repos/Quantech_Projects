//+------------------------------------------------------------------+
//|                                           The_RSI_Engine.mq5 |
//|                                      Copyright 2025, SPLpulse    |
//|                                           https://splpulse.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, The RSI Engine MT5 EA by SPLpluse"
#property link      "https://splpulse.com"
#property version   "2.1" // Fixed data type conversion warning for position ticket

//--- Include the standard MQL5 trading library
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh> // Needed for History Deals
#include <Trade\DealInfo.mqh>

//--- EA INPUT PARAMETERS
//--- Trade Management Group
input group "Trade Management"
input bool   InpUseRiskManagement  = false;     // Use dynamic lot sizing based on risk?
input double InpRiskPercent        = 1.0;      // Risk percentage of equity per trade (if enabled)
input double InpLots               = 0.1;      // Fixed Lot size (if risk management is disabled)
input int    InpStopLossPoints     = 300;      // Stop Loss in points (REQUIRED for risk management)
input int    InpTakeProfitPoints   = 300;      // Take Profit in points
input ulong  InpMagicNumber        = 1901;    // Unique ID for EA's trades

//--- Trailing Stop Group
input group "Trailing Stop"
input bool   InpUseTrailingStop     = true;   // Enable Trailing Stop Loss?
input int    InpTrailingStopTrigger = 3000;   // Profit to trigger trailing stop (in points)
input int    InpTrailingStopStep    = 50;    // Trailing distance from price (in points)

//--- RSI Settings Group
input group "RSI Settings"
input int    InpRSI_Period         = 14;       // Period for the RSI indicator
input int    InpRSI_Overbought     = 70;       // Overbought level
input int    InpRSI_Oversold       = 30;       // Oversold level
input int    InpRSI_Centerline     = 50;       // Centerline level

//--- Strategy Signals & Exits Group
input group "Strategy Signals & Exits"
input bool   InpUse_Divergence_Signal         = true;     // Use RSI Divergence as a primary signal
input bool   InpUse_OverboughtOversold_Reversal = true; // Use Overbought/Oversold reversal as a primary signal
input bool   InpUse_Centerline_Confirmation = true;    // Wait for RSI to cross 50 for entry confirmation
input bool   InpUse_RSI_Level_Exit        = false;     // Exit trades when RSI reaches opposite extreme
input int    InpDivergence_Lookback_Bars    = 60;       // How many bars to look back for divergence

//--- Daily Limits Group
input group "Daily Limits (in Deposit Currency)"
input bool   EnableDailyLimits    = true;     // Enable daily profit/loss limits?
input double DailyProfitTarget    = 10000.0;   // Stop trading for the day if this profit is reached
input double DailyLossLimit       = 5000.0;    // Stop trading for the day if this loss is reached

//--- News Filter Group
input group "News Filter (Server Time)"
input bool   InpUseNewsFilter       = false;    // Enable News Filter?
input int    InpNewsTimeHour        = 15;       // News Event Hour (e.g., 15 for 3 PM)
input int    InpNewsTimeMinute      = 30;       // News Event Minute (e.g., 30)
input int    InpMinutesBeforeNews   = 10;       // Stop trading X minutes BEFORE news
input int    InpMinutesAfterNews    = 10;       // Resume trading X minutes AFTER news

//--- Trading Hours Group
input group "Trading Hours (Server Time)"
input bool   EnableTimeFilter     = false;      // Enable or disable the time filter
input string MondayHours          = "16:30-18:00;09:00-11:00"; // Monday Trading Hours.
input string TuesdayHours         = "16:30-18:00;09:00-11:00"; // Tuesday Trading Hours.
input string WednesdayHours       = "16:30-18:00;09:00-11:00"; // Wednesday Trading Hours.
input string ThursdayHours        = "16:30-18:00;09:00-11:00"; // Thursday Trading Hours.
input string FridayHours          = "16:30-18:00;09:00-11:00"; // Friday Trading Hours.
input string SaturdayHours        = "00:00-00:00"; // Saturday Trading Hours (disabled by default).
input string SundayHours          = "00:00-00:00"; // Sunday Trading Hours (disabled by default).
input bool   CloseAtEndTime       = false;      // Close all trades when a trading session ends?

//--- Global objects and variables
CTrade        trade;
CPositionInfo posInfo;
CAccountInfo  account;
CDealInfo     deal;
int           rsi_handle;

//--- Global state variables for limits
datetime      g_last_limit_check_day = 0;
bool          g_daily_limit_reached = false;


//+------------------------------------------------------------------+
//| Custom RSI Function using the indicator handle                   |
//+------------------------------------------------------------------+
double GetRSI(const int shift)
{
    double rsi_buffer[1];
    if(CopyBuffer(rsi_handle, 0, shift, 1, rsi_buffer) > 0)
    {
        return rsi_buffer[0];
    }
    Print("Error copying RSI buffer - ", GetLastError());
    return -1;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFillingBySymbol(_Symbol);

    rsi_handle = iRSI(_Symbol, _Period, InpRSI_Period, PRICE_CLOSE);
    if(rsi_handle == INVALID_HANDLE)
    {
        Print("Error creating RSI indicator handle - ", GetLastError());
        return(INIT_FAILED);
    }
    
    if(InpUseRiskManagement && InpStopLossPoints <= 0)
    {
        Print("Error: Stop Loss must be greater than 0 to use risk management. EA will not trade.");
        return(INIT_FAILED);
    }

    Print("RSI Multi-Signal EA for MT5 Initialized Successfully.");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(rsi_handle);
    Print("RSI Multi-Signal EA Deinitialized. Reason code: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function (main logic)                                |
//+------------------------------------------------------------------+
void OnTick()
{
    // --- Section for tasks that run on EVERY tick ---
    ManageSessionEnd();
    ManageTrailingStop(); // New trailing stop logic

    // --- Section for tasks that run ONCE PER BAR ---
    static datetime lastBarTime = 0;
    datetime currentTime = iTime(_Symbol, _Period, 0);
    if(lastBarTime == currentTime)
    {
        return; // Not a new bar, so exit
    }
    lastBarTime = currentTime; // It's a new bar, update the time

    // --- New bar logic continues here ---
    if(IsPositionOpen())
    {
        ManageOpenTrades(); // Manages RSI-based exits
    }
    else
    {
        CheckForEntrySignals(); // Looks for new trade opportunities
    }
}

//+------------------------------------------------------------------+
//| Checks for new buy or sell entry signals                         |
//+------------------------------------------------------------------+
void CheckForEntrySignals()
{
    // --- Run all filters before checking for trade signals ---
    if(IsDailyLimitReached()) return;
    if(!IsWithinTradingHours()) return;
    if(IsNewsTimeRestricted()) return;

    bool bullishSignal = false;
    bool bearishSignal = false;

    bool bullishDivergence = InpUse_Divergence_Signal ? CheckBullishDivergence() : false;
    bool bearishDivergence = InpUse_Divergence_Signal ? CheckBearishDivergence() : false;

    bool bullishReversal = InpUse_OverboughtOversold_Reversal ? (GetRSI(2) < InpRSI_Oversold && GetRSI(1) > InpRSI_Oversold) : false;
    bool bearishReversal = InpUse_OverboughtOversold_Reversal ? (GetRSI(2) > InpRSI_Overbought && GetRSI(1) < InpRSI_Overbought) : false;

    if (bullishDivergence || bullishReversal)
    {
        if (InpUse_Centerline_Confirmation)
        {
            if (GetRSI(2) < InpRSI_Centerline && GetRSI(1) > InpRSI_Centerline)
                bullishSignal = true;
        }
        else
        {
            bullishSignal = true;
        }
    }

    if (bearishDivergence || bearishReversal)
    {
        if (InpUse_Centerline_Confirmation)
        {
            if (GetRSI(2) > InpRSI_Centerline && GetRSI(1) < InpRSI_Centerline)
                bearishSignal = true;
        }
        else
        {
            bearishSignal = true;
        }
    }

    // --- LOT SIZING AND MARGIN CHECK ---
    double lots = 0;
    if(InpUseRiskManagement)
    {
        lots = CalculateLotSize();
    }
    else
    {
        lots = NormalizeVolume(InpLots);
    }
    
    if(lots <= 0)
    {
        return;
    }
    
    // --- DIRECTLY PREVENT "NOT ENOUGH MONEY" ERROR ---
    double margin;
    double price = 0;
    ENUM_ORDER_TYPE order_type = WRONG_VALUE;
    
    if(bullishSignal) 
    {
        price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        order_type = ORDER_TYPE_BUY;
    }
    else if(bearishSignal)
    {
        price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        order_type = ORDER_TYPE_SELL;
    }

    if(order_type != WRONG_VALUE)
    {
        if(!OrderCalcMargin(order_type, _Symbol, lots, price, margin))
        {
            Print("Failed to calculate margin. Error: ", GetLastError());
            return;
        }

        if(margin > account.FreeMargin())
        {
            string msg = "Not enough free margin to place trade. Required: " + DoubleToString(margin,2) + 
                         ", Available: " + DoubleToString(account.FreeMargin(),2);
            Print(msg);
            return;
        }
    }
    // --- END MARGIN CHECK ---

    if (bullishSignal)
    {
        double stopLoss = price - InpStopLossPoints * _Point;
        double takeProfit = price + InpTakeProfitPoints * _Point;
        if(InpStopLossPoints == 0) stopLoss = 0;
        if(InpTakeProfitPoints == 0) takeProfit = 0;
    
        trade.Buy(lots, _Symbol, price, stopLoss, takeProfit, "TRE_Buy");
    }
    
    if (bearishSignal)
    {
        double stopLoss = price + InpStopLossPoints * _Point;
        double takeProfit = price - InpTakeProfitPoints * _Point;
        if(InpStopLossPoints == 0) stopLoss = 0;
        if(InpTakeProfitPoints == 0) takeProfit = 0;

        trade.Sell(lots, _Symbol, price, stopLoss, takeProfit, "TRE_Sell");
    }
}

//+------------------------------------------------------------------+
//| Manages currently open trades                                    |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    if(!InpUse_RSI_Level_Exit) return;

    if(posInfo.SelectByMagic(_Symbol, InpMagicNumber))
    {
        double current_rsi = GetRSI(0);
        
        if(posInfo.PositionType() == POSITION_TYPE_BUY && current_rsi >= InpRSI_Overbought)
        {
            trade.PositionClose(posInfo.Ticket()); 
        }
        else if(posInfo.PositionType() == POSITION_TYPE_SELL && current_rsi <= InpRSI_Oversold)
        {
            trade.PositionClose(posInfo.Ticket());
        }
    }
}

//+------------------------------------------------------------------+
//| Checks for Bullish Divergence                                    |
//+------------------------------------------------------------------+
bool CheckBullishDivergence()
{
    const int data_to_copy = InpDivergence_Lookback_Bars + 5;
    double low_prices[];
    double rsi_values[];
    ArraySetAsSeries(low_prices, true);
    ArraySetAsSeries(rsi_values, true);

    if(CopyLow(_Symbol, _Period, 0, data_to_copy, low_prices) < data_to_copy) return false;
    if(CopyBuffer(rsi_handle, 0, 0, data_to_copy, rsi_values) < data_to_copy) return false;
    
    int lookback_half = InpDivergence_Lookback_Bars / 2;
    int recentLowIndex = iLowest(_Symbol, _Period, MODE_LOW, lookback_half, 1);
    int previousLowIndex = iLowest(_Symbol, _Period, MODE_LOW, lookback_half, 1 + lookback_half);

    if(recentLowIndex < 0 || previousLowIndex < 0) return false;

    double recentLowPrice = low_prices[recentLowIndex];
    double previousLowPrice = low_prices[previousLowIndex];
    double rsiAtRecentLow = rsi_values[recentLowIndex];
    double rsiAtPreviousLow = rsi_values[previousLowIndex];

    if (recentLowPrice < previousLowPrice && rsiAtRecentLow > rsiAtPreviousLow)
    {
        if (rsiAtPreviousLow < InpRSI_Oversold + 5)
        {
            Print("Bullish Divergence Detected: Price Lows at bars ", previousLowIndex, " and ", recentLowIndex);
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Checks for Bearish Divergence                                    |
//+------------------------------------------------------------------+
bool CheckBearishDivergence()
{
    const int data_to_copy = InpDivergence_Lookback_Bars + 5;
    double high_prices[];
    double rsi_values[];
    ArraySetAsSeries(high_prices, true);
    ArraySetAsSeries(rsi_values, true);
    
    if(CopyHigh(_Symbol, _Period, 0, data_to_copy, high_prices) < data_to_copy) return false;
    if(CopyBuffer(rsi_handle, 0, 0, data_to_copy, rsi_values) < data_to_copy) return false;

    int lookback_half = InpDivergence_Lookback_Bars / 2;
    int recentHighIndex = iHighest(_Symbol, _Period, MODE_HIGH, lookback_half, 1);
    int previousHighIndex = iHighest(_Symbol, _Period, MODE_HIGH, lookback_half, 1 + lookback_half);

    if(recentHighIndex < 0 || previousHighIndex < 0) return false;

    double recentHighPrice = high_prices[recentHighIndex];
    double previousHighPrice = high_prices[previousHighIndex];
    double rsiAtRecentHigh = rsi_values[recentHighIndex];
    double rsiAtPreviousHigh = rsi_values[previousHighIndex];

    if (recentHighPrice > previousHighPrice && rsiAtRecentHigh < rsiAtPreviousHigh)
    {
        if (rsiAtPreviousHigh > InpRSI_Overbought - 5)
        {
            Print("Bearish Divergence Detected: Price Highs at bars ", previousHighIndex, " and ", recentHighIndex);
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| News Filter: Checks if we are in the no-trade news window        |
//+------------------------------------------------------------------+
bool IsNewsTimeRestricted()
{
    if(!InpUseNewsFilter) return false; // Not restricted if disabled

    datetime current_server_time = TimeCurrent();
    MqlDateTime time_struct;
    TimeToStruct(current_server_time, time_struct);

    time_struct.hour = InpNewsTimeHour;
    time_struct.min  = InpNewsTimeMinute;
    time_struct.sec  = 0;
    datetime news_event_time = StructToTime(time_struct);

    long seconds_before = (long)InpMinutesBeforeNews * 60;
    long seconds_after  = (long)InpMinutesAfterNews * 60;

    datetime no_trade_start_time = (datetime)(news_event_time - seconds_before);
    datetime no_trade_end_time   = (datetime)(news_event_time + seconds_after);

    if(current_server_time >= no_trade_start_time && current_server_time < no_trade_end_time)
    {
        return true; // We are inside the no-trade window
    }

    return false; // Not restricted
}

//+------------------------------------------------------------------+
//| Daily Limits: Checks if daily profit/loss limits have been hit   |
//+------------------------------------------------------------------+
bool IsDailyLimitReached()
{
    if (!EnableDailyLimits) return false; // Limits are disabled, so they can't be reached.

    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    datetime current_day_start = StructToTime(dt) - (dt.hour * 3600 + dt.min * 60 + dt.sec);

    // Reset if it's a new day
    if (g_last_limit_check_day != current_day_start)
    {
        g_last_limit_check_day = current_day_start;
        g_daily_limit_reached = false;
    }

    // If limit was already hit today, stop trading
    if (g_daily_limit_reached) return true;

    // Calculate today's profit/loss
    double todays_profit = 0;
    if (HistorySelect(current_day_start, TimeCurrent()))
    {
        int total_deals = (int)HistoryDealsTotal();
        for (int i = 0; i < total_deals; i++)
        {
            if (deal.SelectByIndex(i) && deal.Magic() == InpMagicNumber)
            {
                todays_profit += deal.Profit() + deal.Commission() + deal.Swap();
            }
        }
    }
    
    // Add floating profit of current positions
    if(posInfo.SelectByMagic(_Symbol, InpMagicNumber))
    {
        todays_profit += posInfo.Profit();
    }

    // Check against limits
    if (todays_profit >= DailyProfitTarget)
    {
        Print("Daily profit target of ", DailyProfitTarget, " reached. Stopping trading for the day.");
        g_daily_limit_reached = true;
        return true; 
    }

    if (todays_profit <= -DailyLossLimit)
    {
        Print("Daily loss limit of ", -DailyLossLimit, " reached. Stopping trading for the day.");
        g_daily_limit_reached = true;
        return true;
    }

    return false; // Limits not reached, trading is allowed.
}

//+------------------------------------------------------------------+
//| Trading Hours: Checks if current time is within allowed sessions |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
    if (!EnableTimeFilter) return true;

    MqlDateTime time;
    TimeToStruct(TimeCurrent(), time);
    int current_minute_of_day = time.hour * 60 + time.min;

    string hours_string = "";
    switch (time.day_of_week)
    {
        case 0: hours_string = SundayHours;   break;
        case 1: hours_string = MondayHours;   break;
        case 2: hours_string = TuesdayHours;  break;
        case 3: hours_string = WednesdayHours;break;
        case 4: hours_string = ThursdayHours; break;
        case 5: hours_string = FridayHours;   break;
        case 6: hours_string = SaturdayHours; break;
    }

    string sessions[];
    int k = StringSplit(hours_string, ';', sessions);

    for (int i = 0; i < k; i++)
    {
        string times[];
        if (StringSplit(sessions[i], '-', times) == 2)
        {
            string start_parts[], end_parts[];
            if (StringSplit(times[0], ':', start_parts) == 2 && StringSplit(times[1], ':', end_parts) == 2)
            {
                // --- FIX: Explicitly cast the result to (int) to remove compiler warning ---
                int start_minute = (int)(StringToInteger(start_parts[0]) * 60 + StringToInteger(start_parts[1]));
                int end_minute   = (int)(StringToInteger(end_parts[0]) * 60 + StringToInteger(end_parts[1]));

                if (current_minute_of_day >= start_minute && current_minute_of_day < end_minute)
                {
                    return true;
                }
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Session Management: Closes trades if session ends                |
//+------------------------------------------------------------------+
void ManageSessionEnd()
{
    if(!CloseAtEndTime) return;

    static bool was_in_session = true; // Assume we start in a session to prevent closing on first tick
    bool is_in_session = IsWithinTradingHours();

    // If we were in a session, but now we are not, close trades.
    if(was_in_session && !is_in_session)
    {
        // Close all positions with the matching magic number
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            if(posInfo.SelectByIndex(i) && posInfo.Magic() == InpMagicNumber)
            {
                Print("Trading session ended. Closing open position #", posInfo.Ticket());
                trade.PositionClose(posInfo.Ticket());
            }
        }
    }

    was_in_session = is_in_session;
}

//+------------------------------------------------------------------+
//| Manages the Trailing Stop for profitable positions               |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
    // Exit if the feature is disabled or inputs are invalid
    if(!InpUseTrailingStop || InpTrailingStopTrigger <= 0 || InpTrailingStopStep <= 0) return;

    // Loop through all open positions from last to first
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        // Select the position and check its magic number and symbol
        if(posInfo.SelectByIndex(i) && posInfo.Magic() == InpMagicNumber && posInfo.Symbol() == _Symbol)
        {
            double current_sl = posInfo.StopLoss();
            double open_price = posInfo.PriceOpen();
            double new_sl = 0;
            ulong ticket = posInfo.Ticket();

            // --- Logic for a BUY position ---
            if(posInfo.PositionType() == POSITION_TYPE_BUY)
            {
                double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                double profit_points = (current_price - open_price) / _Point;

                // Check if the current profit is large enough to trigger the trailing stop
                if(profit_points >= InpTrailingStopTrigger)
                {
                    // Calculate the new potential stop loss price
                    new_sl = current_price - (InpTrailingStopStep * _Point);

                    // We only want to move the stop loss up.
                    // The new SL must be higher than the current SL (or if SL is not set yet)
                    if(new_sl > current_sl || current_sl == 0)
                    {
                        // Also ensure the new SL is at least above the open price to lock in profit
                        if(new_sl > open_price)
                        {
                           trade.PositionModify(ticket, new_sl, posInfo.TakeProfit());
                        }
                    }
                }
            }
            // --- Logic for a SELL position ---
            else if(posInfo.PositionType() == POSITION_TYPE_SELL)
            {
                double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                double profit_points = (open_price - current_price) / _Point;

                // Check if the current profit is large enough to trigger the trailing stop
                if(profit_points >= InpTrailingStopTrigger)
                {
                    // Calculate the new potential stop loss price
                    new_sl = current_price + (InpTrailingStopStep * _Point);

                    // We only want to move the stop loss down.
                    // The new SL must be lower than the current SL (or if SL is not set yet)
                    if(new_sl < current_sl || current_sl == 0)
                    {
                         // Also ensure the new SL is at least below the open price to lock in profit
                         if(new_sl < open_price)
                         {
                            trade.PositionModify(ticket, new_sl, posInfo.TakeProfit());
                         }
                    }
                }
            }
        }
    }
}


//+------------------------------------------------------------------+
//| Utility function to check if a position is currently open        |
//+------------------------------------------------------------------+
bool IsPositionOpen()
{
    // This function now just checks if ANY position for this magic number exists.
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(posInfo.SelectByIndex(i) && posInfo.Magic() == InpMagicNumber)
        {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Calculates lot size based on risk percentage and stop loss       |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    double equity = account.Equity();
    double risk_amount = equity * (InpRiskPercent / 100.0);

    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if(tick_size == 0) return 0.0;
    
    double value_per_point = tick_value / tick_size;
    // Ensure Stop Loss is not zero to prevent division by zero
    double stop_loss_in_price = InpStopLossPoints * _Point;
    if(stop_loss_in_price <= 0) return 0.0;
    
    double stop_loss_money_per_lot = stop_loss_in_price * (value_per_point / _Point);
    
    if(stop_loss_money_per_lot <= 0) return 0.0;

    double lots = risk_amount / stop_loss_money_per_lot;
    
    return NormalizeVolume(lots);
}

//+------------------------------------------------------------------+
//| Normalizes trade volume to broker's requirements                 |
//+------------------------------------------------------------------+
double NormalizeVolume(double volume)
{
    double min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double vol_step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    if(volume < min_volume) volume = min_volume;
    if(volume > max_volume) volume = max_volume;
    
    if(vol_step > 0)
    {
        volume = round(volume / vol_step) * vol_step;
    }
    
    // Re-check after rounding
    if(volume < min_volume) volume = min_volume;
    if(volume > max_volume) volume = max_volume;

    return(volume);
}
//+------------------------------------------------------------------+
