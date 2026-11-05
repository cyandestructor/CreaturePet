import processing.serial.*;
import processing.sound.*;

Serial serialDevice;
int lf = 10;

float maxFood = 1.5;
float food = 1.0;
float hungerRate = 0.0002 * 1;
float hungryThreshold = 0.5;
float starveThreshold = 0.2;
String petHungerState = "Well-fed";
String lastHungerState = "Well-fed"; 

color backgroundColor = #FFF6E5;

PImage cookieImage;
PImage carrotImage;
PImage currentItemImage;
int itemImageTimer = 0;
int itemImageTimerMax = 60;
int itemImageTimerRate = 1;

int petPosX = 0;
int petPosY = 0;
PImage[] petImages;
int currentPetImageSlot;
int previousPetImageSlot;
int secondaryPetImageSlot = -1;
int PET_IDLE = 0, PET_HUNGRY = 1, PET_STARVING = 2, PET_NO = 3, PET_EATING = 4;
int PET_NO_SFX = 0, PET_EATING_SFX = 1, PET_STOMACH_GROWL = 2;

SoundFile imageRelatedSfx;
SoundFile[] petSounds;

void setup() {
  fullScreen();
  //size(800, 800);
  
  if(Serial.list().length > 0){
    serialDevice = new Serial(this, Serial.list()[0], 115200);
    serialDevice.bufferUntil(lf);
  }
  
  petPosX = width/2;
  petPosY = height/2;
  loadPetImages();
  loadPetSounds();
  
  background(backgroundColor);
}

void draw() {
  background(backgroundColor);
  
  imageMode(CENTER);
  
  if(secondaryPetImageSlot == -1) {
    image(petImages[currentPetImageSlot], petPosX, petPosY);
  }
  else {
    image(petImages[secondaryPetImageSlot], petPosX, petPosY);
  }
  
  if(itemImageTimer > 0 && currentItemImage != null) {
    pushMatrix();
    pushStyle();
    
    tint(255, 255 * (float(itemImageTimer) / float(itemImageTimerMax)));
    translate(0, -200 * (float(itemImageTimerMax - itemImageTimer) / float(itemImageTimerMax)));
    
    image(currentItemImage, petPosX - 175, petPosY + 100, 150, 150);
    
    itemImageTimer -= itemImageTimerRate;
    itemImageTimer = max(itemImageTimer, 0);
    
    popStyle();
    popMatrix();
  }
  
  updatePetHunger();
}

void keyPressed() {
  switch(key){
    case 'k':
    evaluateItem("carrot");
    break;
    case 'l':
    evaluateItem("cookie");
    break;
  }
}

void serialEvent(Serial s) {
  String command = s.readString().trim();
  
  if(command.length() != 0){
    evaluateItem(command);
  }
}

void loadPetImages() {
  petImages = new PImage[5];
  
  petImages[0] = loadImage("S_HappyIdle.png");
  petImages[1] = loadImage("S_Hungry.png");
  petImages[2] = loadImage("S_Starving.png");
  petImages[3] = loadImage("S_No.png");
  petImages[4] = loadImage("S_Eating.png");
  
  cookieImage = loadImage("S_Cookie.png");
  carrotImage = loadImage("S_Carrot.png");  
}

void loadPetSounds() {
  petSounds = new SoundFile[3];
  
  petSounds[0] = new SoundFile(this, "no.mp3");
  petSounds[1] = new SoundFile(this, "yum_yum.wav");
  petSounds[2] = new SoundFile(this, "stomach_growling.wav");
}

void feedPet(float foodRestoration) {
  if(food < 0.9) {
    imageRelatedSfx = petSounds[PET_EATING_SFX];
    imageRelatedSfx.play();
    
    showSfxRelatedPetImage(PET_EATING);
    
    food = min(maxFood, food + foodRestoration);
  }
  else {
    imageRelatedSfx = petSounds[PET_NO_SFX];
    imageRelatedSfx.play();
    imageRelatedSfx.amp(0.3);
    
    showSfxRelatedPetImage(PET_NO);
  }
}

void showSfxRelatedPetImage(int imageSlot) {  
  secondaryPetImageSlot = imageSlot;
  thread("updateSfxRelatedImage");
}

void updateSfxRelatedImage() {
  while(imageRelatedSfx != null && imageRelatedSfx.isPlaying()){
      println("Waiting");
  }
  
  secondaryPetImageSlot = -1;
}

void changePetImage(int imageSlot) {
  previousPetImageSlot = currentPetImageSlot;
  
  currentPetImageSlot = imageSlot;
}

void updatePetHunger() {
  float foodBarVibration = 0;
  color foodBarColor = #CB8708;
  float hungerRateBonus = -0.2;
  petHungerState = "Well-fed";
  
  if(food < hungryThreshold && food > starveThreshold) {
    foodBarColor = #C96C08;
    petHungerState = "Hungry";
    foodBarVibration = 0.9;
    hungerRateBonus = 0.1;
  }
  else if(food < starveThreshold) {
    petHungerState = "Starving";
    foodBarColor = #C93208;
    foodBarVibration = 3.0;
    hungerRateBonus = 0.15;
  }
  
  if(petHungerState != lastHungerState) {
    enterHungerState(petHungerState);
  }
  
  pushMatrix();
  translate(random(foodBarVibration), random(foodBarVibration));
  drawProgressBar(food, petPosX, petPosY - 250, 500, 30, foodBarColor, petHungerState, CENTER);
  popMatrix();
  
  if(food > 0) {
    food -= hungerRate * (1.0 + hungerRateBonus);
  }
  else {
    food = 0;
  }
}

void enterHungerState(String newHungerState) {
  switch(newHungerState) {
    case "Well-fed":
    enterWellFedState(lastHungerState);
    break;
    case "Hungry":
    enterHungryState(lastHungerState);
    break;
    case "Starving":
    enterStarvingState(lastHungerState);
    break;
  }
  
  lastHungerState = newHungerState;
  println("I entered: " + newHungerState);
}

void enterWellFedState(String lastState) {
  if(lastState == "Hungry" || lastState == "Starving") {
  }
  
  changePetImage(PET_IDLE);
}

void enterHungryState(String lastState) {
  SoundFile sfx;
  
  if(lastState == "Well-fed") {
    sfx = petSounds[PET_STOMACH_GROWL];
    sfx.play();
    sfx.amp(0.6);
  }
  
  changePetImage(PET_HUNGRY);
}

void enterStarvingState(String lastState) {
  SoundFile sfx;
  
  if(lastState == "Well-fed" || lastState == "Hungry") {
    sfx = petSounds[PET_STOMACH_GROWL];
    sfx.play();
  }
  
  changePetImage(PET_STARVING);
}

void evaluateItem(String item) {
  println("Evaluating Item: " + item);
  
  switch(item.toLowerCase()){
    case "cookie":
    currentItemImage = cookieImage;
    itemImageTimer = itemImageTimerMax;
    
    feedPet(0.25);
    break;
    case "carrot":
    currentItemImage = carrotImage;
    itemImageTimer = itemImageTimerMax;
    
    imageRelatedSfx = petSounds[PET_NO_SFX];
    imageRelatedSfx.play();
    imageRelatedSfx.amp(0.6);
    
    showSfxRelatedPetImage(PET_NO);
    break;
  }
}

void drawProgressBar(float progress, int posX, int posY, int barWidth, int barHeight, color barColor) {
  noStroke();
  // Draw the bar background
  fill(120);
  rect(posX, posY, barWidth, barHeight);
  
  // Draw the progress bar
  fill(barColor);
  int progressWidth = min(int(barWidth * progress), barWidth);
  rect(posX, posY, progressWidth, barHeight);
}

void drawProgressBar(float progress, int posX, int posY, int barWidth, int barHeight, color barColor, int pivotMode) {
  pushMatrix();
  
  if(pivotMode == CENTER){
    translate(-(barWidth/2), -(barHeight/2));
  }
  
  drawProgressBar(progress, posX, posY, barWidth, barHeight, barColor);
  popMatrix();
}

void drawProgressBar(float progress, int posX, int posY, int barWidth, int barHeight, color barColor, String label) {
  textAlign(LEFT);
  fill(0);
  textSize(25);
  text(label, posX, posY - 10);
  drawProgressBar(progress, posX, posY, barWidth, barHeight, barColor);
}

void drawProgressBar(float progress, int posX, int posY, int barWidth, int barHeight, color barColor, String label, int pivotMode) {
  pushMatrix();
  
  if(pivotMode == CENTER){
    translate(-(barWidth/2), -(barHeight/2));
  }
  
  drawProgressBar(progress, posX, posY, barWidth, barHeight, barColor, label);
  popMatrix();
}
