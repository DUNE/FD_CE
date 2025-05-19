// MSU-RTS version 0.5
// 2024-0-21 Dean Shooltz MSU

#if defined(WIRING) && WIRING >= 100
  #include <Wiring.h>
#elif defined(ARDUINO) && ARDUINO >= 100
  #include <Arduino.h>
#else
  #include <WProgram.h>
#endif

#include <Wire.h>
//#include <Adafruit_ADS1015.h>
#include <Adafruit_ADS1X15.h>
#include <TimerOne.h>


// Constants for Teensy pin assignments
const int SYSTEM_ENABLE_RELAY = 0;
const int LED1 = 1;
const int LED2 = 2;
const int LED3 = 3;
const int LN2_VALVE = 4;
//        SCL = 5
//        SDA = 6
const int LED_Immerse = 7;
const int LED_ColdGas = 8;
const int LED_WarmGas = 9;
const int LED_Idle = 10;
const int LCD_Blue = 11;
const int LCD_Green = 12;
const int MuxA = 13;
const int MuxB = 14;
const int MuxC = 15;
const int TC_PURGE_VALVE = 16;
const int SD_CONTROL_VENT_PNEU = 18;
const int SD_CONTROL_VENT = 17;
const int TC_HEAT_RELAY_1 = 19;
const int SD_REFILL_VENT = 20;
const int SD_PRESSURIZE_VALVE = 21;
const int ModeDown = 22;
const int ModeUp = 23;
const int Relay6 = 24;

int inByte = 0;        // incoming serial byte
int Mons = 0;          // Flag for streaming monitoring of input values
int TC_Level = 0;      // Comes from L1-L5
int LevelSensor[8];
int LevelStatus[8];
int Pressure = 0;      // read from ADC from analog sensor
int STATE = 1;       
int PressureADC;
int SD_Level;
int Err_Code = 0;      // start with no Error Code set
int P_Limit_1 = 31500;   // If pressure above this limit, close the SD pressurization valve 
int k = 1;             // general purpose, used for blinking LED1, LED2, LED3
int16_t adc0;          // Force to be unsigned 16 bit integer 
Adafruit_ADS1115 ads;  // Use this for the 16-bit version

void setup()
{
    Serial.begin(19200);

    // Set the relay ports to OUTPUT
    pinMode(SYSTEM_ENABLE_RELAY,OUTPUT);
    pinMode(SD_PRESSURIZE_VALVE,OUTPUT);
    pinMode(SD_CONTROL_VENT,OUTPUT);
    pinMode(TC_PURGE_VALVE,OUTPUT);
    pinMode(TC_HEAT_RELAY_1,OUTPUT);
    pinMode(SD_CONTROL_VENT_PNEU,OUTPUT);
    pinMode(LN2_VALVE,OUTPUT);
    pinMode(SD_REFILL_VENT,OUTPUT);

    // Set the display panel LEDs to OUTPUT
    pinMode(LED_Idle,OUTPUT);
    pinMode(LED_WarmGas,OUTPUT);
    pinMode(LED_ColdGas,OUTPUT);
    pinMode(LED_Immerse,OUTPUT);   

    // Set the extra LED outputs to OUTPUT
    pinMode(LED1,OUTPUT);
    pinMode(LED2,OUTPUT);
    pinMode(LED3,OUTPUT);
     
    // Set the Multiplexer control ports to OUTPUT
    pinMode(MuxA,OUTPUT);
    pinMode(MuxB,OUTPUT);
    pinMode(MuxC,OUTPUT);

    // Set the LCD backlight ports to OUTPUT
    pinMode(LCD_Green,OUTPUT);
    pinMode(LCD_Blue,OUTPUT);

    // Set the mode control switch ports to INPUT
    pinMode(ModeUp, INPUT_PULLUP);
    pinMode(ModeDown, INPUT_PULLUP);

    digitalWrite (LED_Idle,HIGH);
    digitalWrite (LED_WarmGas,HIGH);
    digitalWrite (LED_ColdGas,HIGH);
    digitalWrite (LED_Immerse,HIGH);       
    digitalWrite (LED1,LOW);       
    digitalWrite (LED2,LOW);       
    digitalWrite (LED3,LOW);       

    digitalWrite (MuxA,LOW);
    digitalWrite (MuxB,LOW);
    digitalWrite (MuxC,LOW);
    
    ads.setGain(GAIN_ONE);        // 1x gain   +/- 4.096V  1 bit =  0.125mV
    ads.begin();

    Enable_System();
    SD_Control_Vent_Open();
    delay(1000);
    SetState(1);    
}

void loop(){
  if (Serial.available() > 0) {
    inByte = Serial.read();
    if (inByte == '0'){Serial.println("Setting STATE to 0 (AutoFill)");SetState(0);}
    else if (inByte == '1'){Serial.println("Setting STATE to 1 (IDLE)");SetState(1);ShowPrompt();}
    else if (inByte == '2'){Serial.println("Setting STATE to 2 (TC Warming)");SetState(2);ShowPrompt();}
    else if (inByte == '3'){Serial.println("Setting STATE to 3 (TC LN2 Puddle)");SetState(3);ShowPrompt();}
    else if (inByte == '4'){Serial.println("Setting STATE to 4 (TC LN2 Immersion)");SetState(4);ShowPrompt();}
    else if (inByte == '5'){Serial.println("Setting STATE to 5 (Diags- Take no actions)");SetState(5);ShowPrompt();}
    else if (inByte == 'm'){Serial.println();ShowVals();ShowPrompt();}
    else if (inByte == 'p') {Mons = 0;ShowPrompt();}
    else if (inByte == 'P') {Serial.println();Mons = 1;}
    else if (inByte == 'q') SD_Pressurize_On();  
    else if (inByte == 'a') SD_Pressurize_Off();
    else if (inByte == 'w') SD_Control_Vent_Close();
    else if (inByte == 's') SD_Control_Vent_Open();
    else if (inByte == 'e') TC_Purge_On();
    else if (inByte == 'd') TC_Purge_Off();
    else if (inByte == 'r') Chamber_Heat_On();
    else if (inByte == 'f') Chamber_Heat_Off();
    else if (inByte == 't') SD_LN2_On();
    else if (inByte == 'g') SD_LN2_Off();
    else if (inByte == 'y') SD_Refill_Vent_Close();
    else if (inByte == 'h') SD_Refill_Vent_Open();
    else if (inByte == 'u') Enable_System();
    else if (inByte == 'j') Disable_System();
    else if (inByte == '?'){     
      Serial.println();
      Serial.println("RTS prototype 2024-08-27 10 pm");
      Serial.println("0: AutoFill (any key to abort)");
      Serial.println("1: Idle");
      Serial.println("2: TC Warming");
      Serial.println("3: TC LN2 Puddle");
      Serial.println("4: TC LN2 immersion");
      Serial.println("5: Diags- verbose, take no actions");
      Serial.println("m: Report sensor values");
      Serial.println("P/p: Toggle continuous report sensor values (any key to quit)");
      ShowPrompt();
      }  
    } // end of serial.available command processor

Read_Level_Sensors();  // sets TC_Level and can set STATE = 0 and Err_Code if there is a fault
Get_SD_Pressure(); // sets Pressure
if (Pressure > P_Limit_1) {SD_Pressurize_Off();Serial.println("SD: above P_Limit_1");delay(2000);}

if (Mons == 1) ShowVals();

if (k == 1) {digitalWrite (LED1,HIGH); digitalWrite (LED3,LOW);}
if (k == 2) {digitalWrite (LED2,HIGH); digitalWrite (LED1,LOW);}
if (k == 3) {digitalWrite (LED3,HIGH); digitalWrite (LED2,LOW); k = 0;}
k++;

if (STATE == 0){ 
  AutoFill();
}

if (STATE == 1){ // IDLE
  SD_Pressurize_Off();
  SD_Control_Vent_Open();
  TC_Purge_Off();
  Chamber_Heat_Off();
  SD_LN2_Off();
  if (TC_Level == 0) SD_Refill_Vent_Close();
  else SD_Refill_Vent_Open();

  if (digitalRead(ModeUp)==LOW) {SetState(2);delay(500);}
  else if (digitalRead(ModeDown)==LOW) {SetState(0);delay(500);}
}

else if (STATE == 2){ //Chamber  Warming
  SD_Pressurize_Off();
  SD_Control_Vent_Open();
  TC_Purge_On();
  Chamber_Heat_On();
  SD_LN2_Off();
  if (TC_Level == 0) SD_Refill_Vent_Close();
  else SD_Refill_Vent_Open();

  if (digitalRead(ModeUp)==LOW) {SetState(3);delay(500);}
  else if (digitalRead(ModeDown)==LOW) {SetState(1);delay(500);}
}

else if (STATE == 3){ // Low LN2 in TC
  TC_Purge_Off();
  Chamber_Heat_Off();
  SD_LN2_Off();
  SD_Refill_Vent_Close();
  if(TC_Level == 0) {SD_Pressurize_On(); SD_Control_Vent_Close();}  // LN2 below L1 sensor, try to raise the level
  if(TC_Level == 1) {SD_Pressurize_Off(); SD_Control_Vent_Close();} // Desired LN2 level
  if(TC_Level >= 2) {SD_Pressurize_Off(); SD_Control_Vent_Open();}  // LN2 above L2 sensor, try to lower the level

  if (digitalRead(ModeUp)==LOW) {SetState(4);delay(500);}
  else if (digitalRead(ModeDown)==LOW) {SetState(2);delay(500);}
  }

else if (STATE == 4){ //Immerse
  TC_Purge_Off();
  Chamber_Heat_Off();
  SD_LN2_Off();
  SD_Refill_Vent_Close();
  if(TC_Level <= 2) {SD_Pressurize_On(); SD_Control_Vent_Close();}  // LN2 below L3 sensor, try to raise the level
  if(TC_Level == 3) {SD_Pressurize_Off(); SD_Control_Vent_Close();} // LN2 above L3 but below L4; Desired LN2 level
  if(TC_Level >= 4) {SD_Pressurize_Off(); SD_Control_Vent_Open();}  // LN2 above L4 sensor, try to lower the level

  if (digitalRead(ModeDown)==LOW) {SetState(3);delay(500);}
  }

}

void SetState(int n){
    STATE=n; //STATE is a GLOBAL
    digitalWrite (LED_Idle,LOW);
    digitalWrite (LED_WarmGas,LOW);
    digitalWrite (LED_ColdGas,LOW);
    digitalWrite (LED_Immerse,LOW);   
    if (n==1) {digitalWrite (LED_Idle,HIGH);}
    if (n==2) {digitalWrite (LED_WarmGas,HIGH);}
    if (n==3) {digitalWrite (LED_ColdGas,HIGH);}
    if (n==4) {digitalWrite (LED_Immerse,HIGH);}
    delay(500);
}


void Read_Level_Sensors(){ 
int i=0;
while (i<8){
  SetMux2(i);
  adc0 = ads.readADC_SingleEnded(0);
  LevelSensor[i]=adc0;
  if (adc0 < 10000) LevelStatus[i] = 1;      // Too Low -- shorted out?
  else if (adc0 < 16000) LevelStatus[i] = 2; // ~room temp
  else if (adc0 < 18400) LevelStatus[i] = 3; // in cold gas
  else if (adc0 < 25000) LevelStatus[i] = 4; // immersed
  else LevelStatus[i] = 5;                   // Too High -- open circuit?  
  i++;
}

// LevelSensor[1] is S2 which is special- it is a series of 7 diodes.  The others are 4 didoes in series.
if (LevelSensor[1] < 10000) LevelStatus[1] = 1;      // Too Low -- shorted out?
else if (LevelSensor[1] < 24000) LevelStatus[1] = 2; // ~room temp -- not OK in Dewar!!
else if (LevelSensor[1] < 30000) LevelStatus[1] = 4; // fully immersed
else LevelStatus[1] = 5; // Too High -- open circuit?

TC_Level = 0;
if (LevelStatus[3] == 4) TC_Level = 1;
if (LevelStatus[4] == 4) TC_Level = 2;
if (LevelStatus[5] == 4) TC_Level = 3;
if (LevelStatus[6] == 4) TC_Level = 4;
}

void Get_SD_Pressure(){
adc0 = ads.readADC_SingleEnded(1);
Pressure = adc0;
}

void SetMux2(int ch)
{
   if (ch==0){digitalWrite (MuxC,LOW);digitalWrite (MuxB,LOW);digitalWrite (MuxA,LOW);}
   if (ch==1){digitalWrite (MuxC,HIGH);digitalWrite (MuxB,LOW);digitalWrite (MuxA,LOW);}
   if (ch==2){digitalWrite (MuxC,LOW);digitalWrite (MuxB,HIGH);digitalWrite (MuxA,LOW);}
   if (ch==3){digitalWrite (MuxC,HIGH);digitalWrite (MuxB,HIGH);digitalWrite (MuxA,LOW);}
   if (ch==4){digitalWrite (MuxC,LOW);digitalWrite (MuxB,LOW);digitalWrite (MuxA,HIGH);}
   if (ch==5){digitalWrite (MuxC,HIGH);digitalWrite (MuxB,LOW);digitalWrite (MuxA,HIGH);}
   if (ch==6){digitalWrite (MuxC,LOW);digitalWrite (MuxB,HIGH);digitalWrite (MuxA,HIGH);}
   if (ch==7){digitalWrite (MuxC,HIGH);digitalWrite (MuxB,HIGH);digitalWrite (MuxA,HIGH);}
   delay(100);
}

void ShowPrompt()
{          
     Serial.println();
     Serial.print("RTS> ");
     Serial.send_now();        
}

void ShowVals(){
  Serial.print("State= ");Serial.print(STATE);
  Serial.print(" Press= ");Serial.print(Pressure);
  Serial.print(" L0= ");Serial.print(LevelSensor[0]);
  Serial.print(" L1= ");Serial.print(LevelSensor[1]);
  Serial.print(" L2= ");Serial.print(LevelSensor[2]);
  Serial.print(" L3= ");Serial.print(LevelSensor[3]);
  Serial.print(" L4= ");Serial.print(LevelSensor[4]);
  Serial.print(" L5= ");Serial.print(LevelSensor[5]);
  Serial.print(" L6= ");Serial.print(LevelSensor[6]);
  Serial.print(" L7= ");Serial.println(LevelSensor[7]);
}


void AutoFill(){
  int KeepGoing = 1;
  int FillTime = 0;


  SD_Refill_Vent_Open();
  SD_Pressurize_Off();
  TC_Purge_On();
  Chamber_Heat_On();
  SD_LN2_Off();
  SD_Control_Vent_Open();

  Serial.println();
  Serial.println("Starting AutoFill...");

  delay(1000);

  while (KeepGoing == 1){  
    digitalWrite (LED1,HIGH); digitalWrite (LED2,HIGH); digitalWrite (LED3,HIGH); 
    delay(250);
    digitalWrite (LED1,LOW); digitalWrite (LED2,LOW); digitalWrite (LED3,LOW); 
    delay(250);
    FillTime = FillTime + 1;
    Read_Level_Sensors(); 
    Get_SD_Pressure(); 
    Serial.print("Sec: ");
    Serial.print(FillTime);
    Serial.print(" ");
    ShowVals();

    if (LevelSensor[0] > 18400) {KeepGoing = 0; Serial.println("SD Overfill!!");}
    if (LevelSensor[2] > 18400) {KeepGoing = 0; Serial.println("SD filled to L0 sensor");}
    if (Pressure > 4000) {KeepGoing = 0; Serial.println("SD pressure too high (> 4000) - vent fault?");}
    if (Serial.available() > 0) {KeepGoing = 0; inByte = Serial.read();}
    if (digitalRead(ModeUp)==LOW) KeepGoing = 0;
    if (digitalRead(ModeDown)==LOW) KeepGoing = 0;
    
    if (KeepGoing == 1) SD_LN2_On();
  }

  SD_LN2_Off();
  delay(1000);
  Serial.println("AutoFill ended. Setting State 2 (Warm/Purge)");
  ShowPrompt();
  SetState(2);
}


// System control functions:

void Enable_System(){
  if (STATE == 5) Serial.println("Enabling System");
  digitalWrite (SYSTEM_ENABLE_RELAY,HIGH); 
}
void Disable_System(){
  if (STATE == 5) Serial.println("Disabling System");
  digitalWrite (SYSTEM_ENABLE_RELAY,LOW); 
}

void SD_Pressurize_On(){
  if (STATE == 5) Serial.println("...SD_Pressurize_On");
  if (Pressure < P_Limit_1){digitalWrite (SD_PRESSURIZE_VALVE,HIGH);}
  else {Serial.println("..... Over P_Limit_1, valve not turned on");}
}
void SD_Pressurize_Off(){
  if (STATE == 5) Serial.println("...SD_Pressurize_Off");
  digitalWrite (SD_PRESSURIZE_VALVE,LOW);
}

void SD_Control_Vent_Open(){
  if (STATE == 5) Serial.println("...SD_Vent_Open");
  digitalWrite (SD_CONTROL_VENT,LOW);
}
void SD_Control_Vent_Close(){
  if (STATE == 5) Serial.println("...SD_Vent_Close");
  digitalWrite (SD_CONTROL_VENT,HIGH);
}

void TC_Purge_On(){
  if (STATE == 5) Serial.println("...TC_Purge_On");
  digitalWrite (TC_PURGE_VALVE,HIGH);
}
void TC_Purge_Off(){
  if (STATE == 5) Serial.println("...TC_Purge_Off");
  digitalWrite (TC_PURGE_VALVE,LOW);
}

void Chamber_Heat_On(){
  if (STATE == 5) Serial.println("...Chamber_Heat_On");
  digitalWrite (TC_HEAT_RELAY_1,HIGH);
}
void Chamber_Heat_Off(){
  if (STATE == 5) Serial.println("...Chamber_Heat_Off");
  digitalWrite (TC_HEAT_RELAY_1,LOW);
}

void SD_LN2_On(){
  if (STATE == 5) Serial.println("...SD_LN2_On");
  digitalWrite (LN2_VALVE,HIGH);
}
void SD_LN2_Off(){
  if (STATE == 5) Serial.println("...SD_LN2_Off");
  digitalWrite (LN2_VALVE,LOW);
}

void SD_Refill_Vent_Open(){
  if (STATE == 5) Serial.println("...Refill_Vent_Open");
  digitalWrite (SD_REFILL_VENT,LOW);
}
void SD_Refill_Vent_Close(){
  if (STATE == 5) Serial.println("...Refill_Vent_Close");
  digitalWrite (SD_REFILL_VENT,HIGH);
}
