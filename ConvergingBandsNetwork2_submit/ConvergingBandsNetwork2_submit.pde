/**
 * Converging Bands + Floating Network
 * Processing Java mode sketch, 1200 x 900.
 *
 * Adjusted from two hand-drawn references:
 * 1) Layer 1 reads as five hand-drawn tracks converging into / radiating from a slightly right-shifted center ring.
 * 2) Layer 2 reads as red-gray short marks / point clouds distributed along those directions, rather than large evenly filled regions.
 *
 * Interaction:
 * - Press 1 to toggle layer 1
 * - Press 2 to toggle layer 2
 * - Press g to toggle debug paths / regions
 * - Press r to regenerate particles and point clouds
 */

// =============================================================
// CREATIVE CONTROLS
// Edit this section to quickly adjust palette, mappings, particle size ranges, and overall composition.
// =============================================================

// ─── 1. PALETTE ───────────────────────────────────────────────
color bgColor = color(250,120,240);                // Background color
color bandParticleColor = color(219, 242, 70);  // Layer 1 path particle color
color pathSpineColor = color(93, 82, 210, 0);     // Layer 1 path spine color
color dotColor = color(150, 255, 255, 190);           // Layer 2 primary ring color
color secondaryDotColor = color(222, 219, 242, 160);// Layer 2 secondary ring color
color lineColor = color(222, 219, 242, 255);          // Layer 2 connection color
color centerColor = color(222, 219, 242, 0);      // Center node fill color
color centerRingColor = color(255, 72, 36, 0);    // Center node stroke color
color debugPathColor = color(93, 82, 210, 0);     // Debug path color
color debugRegionColor = color(255, 72, 36, 80);    // Debug region color

// ─── 2. VISIBILITY ────────────────────────────────────────────
boolean SHOW_GUIDES = false;
boolean SHOW_LAYER_1 = true;
boolean SHOW_LAYER_2 = true;
boolean SHOW_PATH_SPINES = true;
boolean SHOW_CENTER_NODE = true;

// ─── 3. WAQI API / WEATHER SOURCE ─────────────────────────────
final String API_KEY = "your_key";
final String CITY = "Shanghai";
final int REFRESH_MS = 60000;

// ─── 4. DATA MAPPING ──────────────────────────────────────────
// AQI -> layer 1 particle count factor. Higher AQI creates denser path particles.
float AQI_INPUT_MIN = 0;
float AQI_INPUT_MAX = 300;
float LAYER1_COUNT_FACTOR_MIN = 0.45;
float LAYER1_COUNT_FACTOR_MAX = 1.85;

// Dominant pollutant -> layer 1 particle size factor. Edit these multipliers for creative tuning.
float PM25_SIZE_FACTOR = 1.35;
float PM10_SIZE_FACTOR = 1.60;
float O3_SIZE_FACTOR = 1.18;
float NO2_SIZE_FACTOR = 1.05;
float SO2_SIZE_FACTOR = 0.92;
float CO_SIZE_FACTOR = 0.82;
float UNKNOWN_POLLUTANT_SIZE_FACTOR = 1.0;

// Temperature -> layer 2 density and size. Higher temperature creates more and larger rings.
float TEMP_INPUT_MIN = -5;
float TEMP_INPUT_MAX = 38;
float LAYER2_COUNT_FACTOR_MIN = 0.48;
float LAYER2_COUNT_FACTOR_MAX = 1.85;
float LAYER2_SIZE_FACTOR_MIN = 0.02;
float LAYER2_SIZE_FACTOR_MAX = 0.25;

// Wind direction -> layer 2 particle direction. 0 keeps purely random motion; 1 strongly follows the wind direction.
float WIND_DIRECTION_MAPPING_STRENGTH = 0.58;
// Wind force -> layer 2 particle speed. Stronger wind makes every particle move faster.
float WIND_INPUT_MIN = 0;
float WIND_INPUT_MAX = 12;
float LAYER2_SPEED_FACTOR_MIN = 0.45;
float LAYER2_SPEED_FACTOR_MAX = 2.25;

// ─── 5. COMPOSITION ───────────────────────────────────────────
// Scale paths and layer 2 regions around the center; values above 1 extend them beyond the canvas.
float COMPOSITION_SCALE = 1.16;
// Extra outward extension for edge layer 2 regions, useful for the beyond-the-canvas effect.
float EDGE_REGION_EXTENSION = 150;

// ─── 6. CANVAS + CENTER NODE ─────────────────────────────────
int CANVAS_W = 1200;
int CANVAS_H = 900;
PVector center;
float centerCircleSize = 128;
float centerRingWeight = 3.4;

// ─── 7. LAYER 1 PARTICLES ────────────────────────────────────
int squareParticleCount = 820;
float BAND_WIDTH = 100;
float squareMinSize = 3.4;
float squareMaxSize = 12.5;
float squareSpeedMin = 0.0018;
float squareSpeedMax = 0.0068;
float squareRotationJitter = 0.18;
float centerAlphaBoost = 62;
float centerGatherPower = 2.15;
float pathGuideStep = 0.02;
float pathSpineWeight = 2.8;

// ─── 8. LAYER 2 RING NETWORK ─────────────────────────────────
int dotsPerRegion = 72;
float dotMinSize = 10.0;
float dotMaxSize = 22.0;
float dotSpeedMin = 0.18;
float dotSpeedMax = 0.82;
float dotRingWeightMin = 1.5;
float dotRingWeightMax = 3.6;
float dotNoiseStrength = 0.075;
float dotWanderStrength = 0.10;
float connectionDistance = 142;
float connectionProbability = 0.40;
float crossRegionConnectionProbability = 0.18;
float connectionStrokeWeight = 1.45;
float dotGuideVertexSize = 5;
float secondaryDotProbability = 0.34;

// ─── 9. RUNTIME WEATHER STATE ────────────────────────────────
String waqiUrl;
int lastWeatherFetchMs = -REFRESH_MS;
String weatherStatus = "waiting for WAQI data";
int currentAqi = 85;
String currentDominantPollutant = "pm25";
float currentTemperature = 22;
float currentWind = 2.5;
float layer1CountFactor = 1.0;
float layer1SizeFactor = 1.0;
float currentWindDirectionDegrees = 115;
float layer2SpeedFactor = 1.0;
float layer2CountFactor = 1.0;
float layer2SizeFactor = 1.0;
float windDirectionBlend = 0.35;

ArrayList<FlowPath> paths = new ArrayList<FlowPath>();
ArrayList<SquareParticle> squareParticles = new ArrayList<SquareParticle>();
ArrayList<PolygonRegion> regions = new ArrayList<PolygonRegion>();
ArrayList<NetworkDot> networkDots = new ArrayList<NetworkDot>();



void setup() {
    size(1200,900);
  smooth(8);
  rectMode(CENTER);
  ellipseMode(CENTER);

  center = new PVector(width * 0.505, height * 0.475);
  waqiUrl = "https://api.waqi.info/feed/" + CITY + "/?token=" + API_KEY;

  fetchWeatherData();
  initPaths();
  initRegions();
  initParticles();
}

void draw() {
  if (millis() - lastWeatherFetchMs > REFRESH_MS) {
    fetchWeatherData();
  }

  background(bgColor);

  if (SHOW_LAYER_1) {
    drawLayer1();
  }

  if (SHOW_LAYER_2) {
    drawLayer2();
  }

  if (SHOW_CENTER_NODE) {
    drawCenterNode();
  }

  if (SHOW_GUIDES) {
    drawGuides();
  }
}

void keyPressed() {
  if (key == '1') {
    SHOW_LAYER_1 = !SHOW_LAYER_1;
  } else if (key == '2') {
    SHOW_LAYER_2 = !SHOW_LAYER_2;
  } else if (key == 'g' || key == 'G') {
    SHOW_GUIDES = !SHOW_GUIDES;
  } else if (key == 'r' || key == 'R') {
    initParticles();
  } else {
    fetchWeatherData();
  }
      if (key == 's' || key == 'S') {  // 按 S 键保存
    saveFrame("wallpaper-####.png");
    
    }
}


// =============================================================
// WAQI data access and visual mapping
// =============================================================

void fetchWeatherData() {
  lastWeatherFetchMs = millis();

  JSONObject response = null;
  try {
    response = loadJSONObject(waqiUrl);
  } catch (Exception e) {
    weatherStatus = "WAQI request failed; using previous values";
    return;
  }

  if (response == null) {
    weatherStatus = "WAQI request failed; using previous values";
    return;
  }

  if (!"ok".equals(response.getString("status", ""))) {
    weatherStatus = "WAQI status: " + response.getString("status", "unknown");
    return;
  }

  JSONObject data = response.getJSONObject("data");
  if (data == null) {
    weatherStatus = "WAQI response missing data";
    return;
  }

  currentAqi = parseAqi(data.getString("aqi", str(currentAqi)));
  currentDominantPollutant = data.getString("dominentpol", currentDominantPollutant);

  JSONObject iaqi = data.getJSONObject("iaqi");
  if (iaqi != null) {
    currentTemperature = getIaqiValue(iaqi, "t", currentTemperature);
    currentWind = getIaqiValue(iaqi, "w", currentWind);
    currentWindDirectionDegrees = getIaqiValue(iaqi, "wd", currentWindDirectionDegrees);
  }

  applyWeatherMappings();
  initParticles();
  weatherStatus = "WAQI " + CITY + " | AQI " + currentAqi + " | " + currentDominantPollutant +
    " | temp " + nf(currentTemperature, 0, 1) + "C | wind speed " + nf(currentWind, 0, 1) +
    " | wind dir " + nf(currentWindDirectionDegrees, 0, 0) + "deg";
}

int parseAqi(String rawValue) {
  if (rawValue == null || rawValue.equals("-")) {
    return currentAqi;
  }
  return max(0, round(float(rawValue)));
}

float getIaqiValue(JSONObject iaqi, String keyName, float fallback) {
  if (!iaqi.hasKey(keyName)) {
    return fallback;
  }
  JSONObject item = iaqi.getJSONObject(keyName);
  if (item == null || !item.hasKey("v")) {
    return fallback;
  }
  return item.getFloat("v", fallback);
}

void applyWeatherMappings() {
  layer1CountFactor = map(constrain(currentAqi, AQI_INPUT_MIN, AQI_INPUT_MAX),
    AQI_INPUT_MIN, AQI_INPUT_MAX, LAYER1_COUNT_FACTOR_MIN, LAYER1_COUNT_FACTOR_MAX);
  layer1SizeFactor = pollutantSizeFactor(currentDominantPollutant);
  float constrainedTemperature = constrain(currentTemperature, TEMP_INPUT_MIN, TEMP_INPUT_MAX);
  layer2CountFactor = map(constrainedTemperature,
    TEMP_INPUT_MIN, TEMP_INPUT_MAX, LAYER2_COUNT_FACTOR_MIN, LAYER2_COUNT_FACTOR_MAX);
  layer2SizeFactor = map(constrainedTemperature,
    TEMP_INPUT_MIN, TEMP_INPUT_MAX, LAYER2_SIZE_FACTOR_MIN, LAYER2_SIZE_FACTOR_MAX);
  layer2SpeedFactor = map(constrain(currentWind, WIND_INPUT_MIN, WIND_INPUT_MAX),
    WIND_INPUT_MIN, WIND_INPUT_MAX, LAYER2_SPEED_FACTOR_MIN, LAYER2_SPEED_FACTOR_MAX);
  windDirectionBlend = constrain(WIND_DIRECTION_MAPPING_STRENGTH, 0, 1);
}

float pollutantSizeFactor(String pollutant) {
  String p = pollutant.toLowerCase();
  if (p.equals("pm25")) {
    return PM25_SIZE_FACTOR;
  }
  if (p.equals("pm10")) {
    return PM10_SIZE_FACTOR;
  }
  if (p.equals("o3")) {
    return O3_SIZE_FACTOR;
  }
  if (p.equals("no2")) {
    return NO2_SIZE_FACTOR;
  }
  if (p.equals("so2")) {
    return SO2_SIZE_FACTOR;
  }
  if (p.equals("co")) {
    return CO_SIZE_FACTOR;
  }
  return UNKNOWN_POLLUTANT_SIZE_FACTOR;
}

PVector pt(float x, float y) {
  PVector p = new PVector(x, y);
  p.sub(center);
  p.mult(COMPOSITION_SCALE);
  p.add(center);
  return p;
}

PVector centerOffset(float xOffset, float yOffset) {
  return new PVector(center.x + xOffset * COMPOSITION_SCALE, center.y + yOffset * COMPOSITION_SCALE);
}

// =============================================================
// Initialization: paths, regions, particles
// =============================================================

void initPaths() {
  paths.clear();

  // a. Left long line: starts beyond the left edge so the enlarged path feels like it passes through the canvas.
  paths.add(new FlowPath(new PVector[] {
    pt(-120, 545),
    pt(230, 505),
    pt(430, 462),
    centerOffset(-42, -30),
    center.copy()
  }));

  // b. Right slender line: enters the center from beyond the right edge.
  paths.add(new FlowPath(new PVector[] {
    pt(CANVAS_W + 125, 382),
    pt(910, 435),
    pt(735, 480),
    centerOffset(60, 12),
    center.copy()
  }));

  // c. Upper curved line: drops toward the center from above the canvas.
  paths.add(new FlowPath(new PVector[] {
    pt(535, -110),
    pt(585, 175),
    pt(642, 325),
    pt(628, 430),
    center.copy()
  }));

  // d. Lower vertical line: converges toward the center from below the canvas.
  paths.add(new FlowPath(new PVector[] {
    pt(548, CANVAS_H + 135),
    pt(558, 735),
    pt(560, 585),
    centerOffset(-52, 38),
    center.copy()
  }));

  // e. Lower-right arc: bends into the center from outside the lower-right canvas area.
  paths.add(new FlowPath(new PVector[] {
    pt(CANVAS_W + 120, CANVAS_H + 85),
    pt(855, 660),
    pt(710, 548),
    centerOffset(48, 52),
    center.copy()
  }));
}

void initRegions() {
  regions.clear();
  float e = EDGE_REGION_EXTENSION;

  // Layer 2 now reads as one branching, hand-drawn field like the reference image:
  // a diagonal lower-left-to-upper-right body, plus upper-left, right, and lower branches
  // that all meet around the center as a single overall shape.

  // a. Upper-left branch: clipped by the top edge and tapering into the central knot.
  regions.add(new PolygonRegion(new PVector[] {
    pt(210, -e), pt(430, -e * 0.55), pt(535, 205),
    pt(570, 325), pt(500, 375), pt(390, 180)
  }, new PVector(0.34, 0.94)));

  // b. Upper-right branch: the broad fan that rises from the knot and exits the top-right.
  regions.add(new PolygonRegion(new PVector[] {
    pt(760, -e), pt(CANVAS_W + e, 70), pt(930, 250),
    pt(740, 330), pt(620, 410), pt(610, 290)
  }, new PVector(0.82, -0.56)));

  // c. Lower-left body: the strongest diagonal stroke entering the central crossing.
  regions.add(new PolygonRegion(new PVector[] {
    pt(-e, 720), pt(120, 610), pt(365, 500),
    pt(555, 365), pt(610, 430), pt(430, 560),
    pt(170, 760), pt(-e, 835)
  }, new PVector(0.82, -0.57)));

  // d. Right branch: a slimmer horizontal arm that breaks out toward the right edge.
  regions.add(new PolygonRegion(new PVector[] {
    pt(625, 385), pt(820, 395), pt(CANVAS_W + e, 505),
    pt(CANVAS_W + e, 640), pt(930, 585), pt(720, 470),
    pt(600, 445)
  }, new PVector(0.98, 0.22)));

  // e. Lower branch: the vertical tail dropping from the central knot.
  regions.add(new PolygonRegion(new PVector[] {
    pt(535, 430), pt(660, 455), pt(660, 645),
    pt(585, CANVAS_H + e), pt(455, CANVAS_H + e), pt(470, 635),
    pt(490, 505)
  }, new PVector(-0.08, 1.0)));
}

void initParticles() {
  squareParticles.clear();
  networkDots.clear();

  if (paths.size() > 0) {
    int weatherDrivenSquareCount = max(paths.size(), round(squareParticleCount * layer1CountFactor));
    for (int i = 0; i < weatherDrivenSquareCount; i++) {
      FlowPath p = paths.get(i % paths.size());
      squareParticles.add(new SquareParticle(p));
    }
  }

  int weatherDrivenDotsPerRegion = max(1, round(dotsPerRegion * layer2CountFactor));
  for (PolygonRegion region : regions) {
    for (int i = 0; i < weatherDrivenDotsPerRegion; i++) {
      networkDots.add(new NetworkDot(region));
    }
  }
}

// =============================================================
// Draw the two visual layers
// =============================================================

void drawLayer1() {
  if (SHOW_PATH_SPINES) {
    for (FlowPath p : paths) {
      p.displaySpine();
    }
  }

  for (SquareParticle sp : squareParticles) {
    sp.update();
    sp.display();
  }
}

void drawLayer2() {
  for (NetworkDot d : networkDots) {
    d.update();
  }

  strokeWeight(connectionStrokeWeight);
  for (int i = 0; i < networkDots.size(); i++) {
    NetworkDot a = networkDots.get(i);
    for (int j = i + 1; j < networkDots.size(); j++) {
      NetworkDot b = networkDots.get(j);
      float distance = PVector.dist(a.pos, b.pos);
      float probability = (a.originRegion == b.originRegion) ? connectionProbability : crossRegionConnectionProbability;
      if (distance < connectionDistance && random(1) < probability) {
        float distanceAlpha = map(distance, 0, connectionDistance, alpha(lineColor), 0);
        stroke(lineColor, distanceAlpha);
        line(a.pos.x, a.pos.y, b.pos.x, b.pos.y);
      }
    }
  }

  for (NetworkDot d : networkDots) {
    d.display();
  }
}

void drawCenterNode() {
  noStroke();
  fill(centerColor);
  ellipse(center.x, center.y, centerCircleSize, centerCircleSize);

  noFill();
  stroke(centerRingColor);
  strokeWeight(centerRingWeight);
  ellipse(center.x - 30, center.y - 22, centerCircleSize * 0.55, centerCircleSize * 0.62);

  // Add a short darker gathering line on the right side of the center, echoing the heavier mark near the ring in the first sketch.
  stroke(centerRingColor);
  strokeWeight(centerRingWeight + 0.8);
  line(center.x - 4, center.y + 16, center.x + 58, center.y - 2);
}

void drawGuides() {
  for (FlowPath p : paths) {
    p.displayGuide();
  }

  for (PolygonRegion r : regions) {
    r.displayGuide();
  }
}

// =============================================================
// class FlowPath
// Stores path control points and provides path position, direction, and in-band positions.
// =============================================================

class FlowPath {
  ArrayList<PVector> pts = new ArrayList<PVector>();

  FlowPath(PVector[] inputPts) {
    for (PVector p : inputPts) {
      pts.add(p.copy());
    }
  }

  PVector getPoint(float t) {
    t = constrain(t, 0, 1);
    int segmentCount = pts.size() - 1;
    float scaled = t * segmentCount;
    int seg = min(floor(scaled), segmentCount - 1);
    float localT = scaled - seg;

    PVector p0 = pts.get(max(seg - 1, 0));
    PVector p1 = pts.get(seg);
    PVector p2 = pts.get(seg + 1);
    PVector p3 = pts.get(min(seg + 2, pts.size() - 1));

    float x = catmullRom(p0.x, p1.x, p2.x, p3.x, localT);
    float y = catmullRom(p0.y, p1.y, p2.y, p3.y, localT);
    return new PVector(x, y);
  }

  PVector getDirection(float t) {
    float dt = 0.004;
    PVector a = getPoint(constrain(t - dt, 0, 1));
    PVector b = getPoint(constrain(t + dt, 0, 1));
    PVector dir = PVector.sub(b, a);
    if (dir.magSq() < 0.0001) {
      dir = new PVector(1, 0);
    }
    dir.normalize();
    return dir;
  }

  PVector getBandPosition(float t, float offset) {
    PVector pos = getPoint(t);
    PVector dir = getDirection(t);
    PVector normal = new PVector(-dir.y, dir.x);
    normal.mult(offset);
    pos.add(normal);
    return pos;
  }

  void displaySpine() {
    noFill();
    stroke(pathSpineColor);
    strokeWeight(pathSpineWeight);
    beginShape();
    for (float t = 0; t <= 1.0001; t += pathGuideStep) {
      PVector p = getPoint(t);
      vertex(p.x, p.y);
    }
    endShape();
  }

  void displayGuide() {
    noFill();
    stroke(debugPathColor);
    strokeWeight(BAND_WIDTH);
    beginShape();
    for (float t = 0; t <= 1.0001; t += pathGuideStep) {
      PVector p = getPoint(t);
      vertex(p.x, p.y);
    }
    endShape();

    stroke(debugPathColor, alpha(debugPathColor));
    strokeWeight(2);
    beginShape();
    for (float t = 0; t <= 1.0001; t += pathGuideStep) {
      PVector p = getPoint(t);
      vertex(p.x, p.y);
    }
    endShape();
  }
}

float catmullRom(float a, float b, float c, float d, float t) {
  float t2 = t * t;
  float t3 = t2 * t;
  return 0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3);
}

// =============================================================
// class SquareParticle
// Belongs to a FlowPath and moves along t from 0 to 1, traveling from the far end toward the center.
// =============================================================

class SquareParticle {
  FlowPath path;
  float t;
  float speed;
  float offset;
  float size;
  float rotationOffset;

  SquareParticle(FlowPath path) {
    this.path = path;
    reset(true);
  }

  void reset(boolean scatterAlongPath) {
    t = scatterAlongPath ? random(1) : 0;
    speed = random(squareSpeedMin, squareSpeedMax);
    offset = random(-BAND_WIDTH * 0.5, BAND_WIDTH * 0.5);
    size = random(squareMinSize, squareMaxSize) * layer1SizeFactor;
    rotationOffset = random(-squareRotationJitter, squareRotationJitter);
  }

  void update() {
    t += speed;
    if (t > 1) {
      reset(false);
    }
  }

  void display() {
    PVector pos = path.getBandPosition(t, offset);
    PVector dir = path.getDirection(t);
    float angle = atan2(dir.y, dir.x) + rotationOffset;
    float centerGain = pow(constrain(t, 0, 1), centerGatherPower);
    float particleAlpha = min(255, alpha(bandParticleColor) + centerGain * centerAlphaBoost);

    pushMatrix();
    translate(pos.x, pos.y);
    rotate(angle);
    noStroke();
    fill(bandParticleColor, particleAlpha);
    rect(0, 0, size, size);
    popMatrix();
  }
}

// =============================================================
// class PolygonRegion
// Stores polygon vertices and handles point-in-polygon checks, random interior points, and debug outlines.
// flowDir controls the approximate direction of short marks in the second sketch reference.
// =============================================================

class PolygonRegion {
  ArrayList<PVector> vertices = new ArrayList<PVector>();
  PVector flowDir;
  float minX;
  float maxX;
  float minY;
  float maxY;

  PolygonRegion(PVector[] inputVertices, PVector inputFlowDir) {
    flowDir = inputFlowDir.copy();
    if (flowDir.magSq() < 0.0001) {
      flowDir = new PVector(1, 0);
    }
    flowDir.normalize();

    minX = Float.MAX_VALUE;
    maxX = -Float.MAX_VALUE;
    minY = Float.MAX_VALUE;
    maxY = -Float.MAX_VALUE;

    for (PVector p : inputVertices) {
      vertices.add(p.copy());
      minX = min(minX, p.x);
      maxX = max(maxX, p.x);
      minY = min(minY, p.y);
      maxY = max(maxY, p.y);
    }
  }

  boolean contains(PVector p) {
    boolean inside = false;
    int count = vertices.size();
    for (int i = 0, j = count - 1; i < count; j = i++) {
      PVector vi = vertices.get(i);
      PVector vj = vertices.get(j);
      boolean intersect = ((vi.y > p.y) != (vj.y > p.y)) &&
        (p.x < (vj.x - vi.x) * (p.y - vi.y) / (vj.y - vi.y) + vi.x);
      if (intersect) {
        inside = !inside;
      }
    }
    return inside;
  }

  PVector randomPointInside() {
    for (int attempt = 0; attempt < 1000; attempt++) {
      PVector candidate = new PVector(random(minX, maxX), random(minY, maxY));
      if (contains(candidate)) {
        return candidate;
      }
    }

    PVector fallback = new PVector(0, 0);
    for (PVector v : vertices) {
      fallback.add(v);
    }
    fallback.div(vertices.size());
    return fallback;
  }

  void displayGuide() {
    noFill();
    stroke(debugRegionColor);
    strokeWeight(2);
    beginShape();
    for (PVector v : vertices) {
      vertex(v.x, v.y);
    }
    endShape(CLOSE);

    noStroke();
    fill(debugRegionColor);
    for (PVector v : vertices) {
      ellipse(v.x, v.y, dotGuideVertexSize, dotGuideVertexSize);
    }
  }
}

// =============================================================
boolean isInsideAnyLayer2Region(PVector point) {
  for (PolygonRegion region : regions) {
    if (region.contains(point)) {
      return true;
    }
  }
  return false;
}

boolean isInsideLayer2Field(PVector point) {
  // Keep layer 2 particles inside the five edge regions so they do not drift onto the layer 1 roads.
  return isInsideAnyLayer2Region(point);
}

PVector randomLayer2Point() {
  if (regions.size() == 0) {
    return center.copy();
  }

  PolygonRegion region = regions.get(floor(random(regions.size())));
  return region.randomPointInside();
}

// =============================================================
PVector windDirectionVector() {
  // WAQI wind direction is interpreted as meteorological degrees; particles move downwind on screen.
  float screenAngle = radians(currentWindDirectionDegrees + 90);
  return PVector.fromAngle(screenAngle);
}

PVector initialWindMappedVelocity(float baseSpeed) {
  PVector randomDir = PVector.random2D();
  PVector windDir = windDirectionVector();
  float blend = constrain(windDirectionBlend, 0, 1);
  windDir.mult(blend);
  randomDir.mult(1.0 - blend);
  PVector mappedDir = PVector.add(randomDir, windDir);
  if (mappedDir.magSq() < 0.0001) {
    mappedDir = PVector.random2D();
  }
  mappedDir.normalize();
  mappedDir.rotate(random(-0.42, 0.42) * (1.0 - blend));
  // Wind force controls the particle speed, while wind direction only biases the heading.
  mappedDir.mult(baseSpeed * layer2SpeedFactor);
  return mappedDir;
}

// =============================================================
// class NetworkDot
// Initially belongs to one PolygonRegion and stays inside the unified branching layer 2 field.
// =============================================================

class NetworkDot {
  PolygonRegion originRegion;
  PVector pos;
  PVector vel;
  float baseSpeed;
  float size;
  float noiseSeed;
  boolean useSecondaryColor;

  NetworkDot(PolygonRegion region) {
    originRegion = region;
    pos = region.randomPointInside();
    baseSpeed = random(dotSpeedMin, dotSpeedMax);
    vel = initialWindMappedVelocity(baseSpeed);
    size = random(dotMinSize, dotMaxSize) * layer2SizeFactor;
    noiseSeed = random(1000);
    useSecondaryColor = random(1) < secondaryDotProbability;
  }

  void update() {
    float noiseAngle = noise(noiseSeed, frameCount * dotNoiseStrength) * TWO_PI * 2;
    PVector wander = PVector.fromAngle(noiseAngle);
    wander.mult(dotWanderStrength);
    vel.add(wander);
    PVector windSteer = windDirectionVector();
    windSteer.mult(dotWanderStrength * windDirectionBlend);
    vel.add(windSteer);

    // Re-apply the wind-force speed mapping every frame so each particle responds to wind speed.
    vel.setMag(baseSpeed * layer2SpeedFactor);

    PVector next = PVector.add(pos, vel);
    if (isInsideLayer2Field(next)) {
      pos.set(next);
    } else {
      vel.rotate(PI + random(-0.55, 0.55));
      vel.mult(0.72);
      PVector bounced = PVector.add(pos, vel);
      if (isInsideLayer2Field(bounced)) {
        pos.set(bounced);
      } else {
        pos = randomLayer2Point();
        vel = initialWindMappedVelocity(baseSpeed);
      }
    }

    noiseSeed += 0.002;
  }

  void display() {
    noFill();
    stroke(useSecondaryColor ? secondaryDotColor : dotColor);
    strokeWeight(map(size, dotMinSize * LAYER2_SIZE_FACTOR_MIN, dotMaxSize * LAYER2_SIZE_FACTOR_MAX, dotRingWeightMin, dotRingWeightMax));
    float ringSize = size;
    ellipse(pos.x, pos.y, ringSize, ringSize);
  }
}
