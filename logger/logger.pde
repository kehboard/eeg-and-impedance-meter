import processing.serial.*;

import java.nio.*;
import java.util.List;
import java.util.ArrayList;
import java.util.Date;

// Processing plotting library
import grafica.*;
// Processing GUI library
import controlP5.*;



private final int nChannels = 2;  // also number of plots
private final int intSize = 4;  // bytes

private final int plotWidth = 800;
private final int plotHeight = 600;

private final int pauseBtnWidth = plotWidth * nChannels;
private final int pauseBtnHeight = 40;

// Array of points for 2 channels
private final List<Integer>[] channels = new List[nChannels];
// Store last 2 integers (1 per each channel)
//private final byte[] currentBuffer = new byte[nChannels * intSize];
// Use this class to interpret bytes as integers
// private ByteBuffer byteBuffer;

private final int nPoints = 200;  // num of points in each plot (generally affects resolution and speed)
private int pointsCnt = 0;  // count each new point
private final float scatterCoef = 1f;
private final GPlot[] plots = new GPlot[nChannels];
private boolean isPaused = false;

// For x-ticks
private long startTime;
private long currentTime;
private long currentTimePrev;

// For benchmarking
private final boolean runBench = false;
private int cnt;
private final int skipNFirstPoints = 100;
private int skipNFirstPointsCnt = 0;

/*
 *  Use Processing GUI framework to add play/pause button. This is a pretty rich library
 *  so you can put some other useful elements
 */
private ControlP5 cp5;
Table table;


public void settings() {
  size(plotWidth * nChannels, plotHeight + pauseBtnHeight);
}



public void setup() {
  table = new Table();
  table.addColumn("timestamp");
  table.addColumn("EEG");
  table.addColumn("Impedance");
  for (int i = 0; i < channels.length; i++) {
    channels[i] = new ArrayList();
  }

  for (int i = 0, posX = 0; i < plots.length; i++, posX += plotWidth) {
    plots[i] = new GPlot(this);
    plots[i].getMainLayer().setPointSize(3.5f);
    plots[i].setPoints(new GPointsArray());
    plots[i].setPos(posX, 0);
     plots[i].setOuterDim(plotWidth,plotHeight);
    //plots[i].setYLim(0, 4095);
    plots[i].defaultDraw();
  }

  cp5 = new ControlP5(this);
  cp5.addButton("pauseBtn")
    .setPosition(0, plotHeight)
    .setSize(pauseBtnWidth, pauseBtnHeight);

  String portName = "COM5";
  Serial ser = new Serial(this, portName, 9600);
  ser.bufferUntil(10);
  //ser.buffer(4096);

  startTime = System.nanoTime();
  currentTimePrev = startTime;
}



public void draw() {
  currentTime = System.nanoTime();

  // Benchmark - how many points in 1 second
  if ( runBench ) {
    cnt += channels[0].size();
    if (currentTime - startTime >= 1e9) {
      println(cnt);
      cnt = 0;
      startTime = currentTime;
    }
    // Controlling whether values are correct when benchmarking
    if ( ++skipNFirstPointsCnt == skipNFirstPoints ) {
      System.out.printf("A: %4d\tB: %4d\n", channels[0].get(0), channels[1].get(0));
    }
  } else {

    /*
             *  No need to redraw during the pause. But we continue to stamp points in the background
     *  to provide an instant resuming
     */
    if (!isPaused) {
      for (GPlot plot : plots) {
        plot.beginDraw();
        plot.drawBackground();
        plot.drawBox();
        plot.drawXAxis();
        plot.drawYAxis();
        plot.drawLines();
        plot.drawTopAxis();
        plot.drawRightAxis();
        plot.drawTitle();
        plot.getMainLayer().drawPoints();
        plot.endDraw();
      }
    }

    /*
             *  Append all points accumulated between 2 consecutive screen updates (see 'serialEvent' note).
     *  Instead of putting all these accumulated points at the one x-tick we evenly scatter them
     *  a little bit with a 'scatterCoef' to avoid gaps between points.
     */
    for (int i = 0; i < channels[0].size(); i++, pointsCnt++) {
      for (int j = 0; j < plots.length; j++) {
        plots[j].addPoint((currentTimePrev
          + ((currentTime - currentTimePrev) *i/* scatterCoef * i*/ / channels[j].size())
          - startTime)
          / 1e9f, 
          channels[j].get(i));
      }
      if (pointsCnt > nPoints) {
        for (GPlot plot : plots) {
          plot.removePoint(0);
        }
      }
    }
    currentTimePrev = currentTime;
  }

  // Free dynamic buffers
  for (List<Integer> channel : channels) {
    channel.clear();
  }
}



/*
 *  We use this separate event to read bytes from the serial port. 'currentBuffer' is used to store raw
 *  bytes and 'byteBuffer' to convert them into 2 4-byte integers (little endian format). As 'serialEvent'
 *  triggers more frequent than screen update event we need to store several values between 2 updates.
 *  So we use dynamic arrays for this purpose.
 *
 *  Also there are always a chance to get in during a 'wrong' byte: not a first one of a whole integer or
 *  just channels are swapped. In this case simply restart the sketch or implement some sort of syncing
 *  mechanism (e.g. check decoded values).
 */
public void serialEvent(Serial s) {
  //s.readBytes(currentBuffer);
  String myString = s.readString();
  float[] data = float(split(myString, ' '));
  //byteBuffer = ByteBuffer.wrap(currentBuffer).order(ByteOrder.LITTLE_ENDIAN);
  int i =0;
  for (List<Integer> channel : channels) {
    print(myString);
    channel.add(int(data[i]));
    i++;
  }


    TableRow newRow = table.addRow();
    newRow.setLong("timestamp", new Date().getTime());
    newRow.setFloat("EEG", data[1]);
    newRow.setFloat("Impedance", data[0]);
    saveTable(table, "data/new.csv");
}



/*
 *  Our button automatically binds itself to the function with matching name
 */
public void pauseBtn() {
  isPaused = !isPaused;
}
