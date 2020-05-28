/* This macro uses segmented file of a single fish swimming in a dish.  It finds the coordinates of the fish which are then used to measure its displacements.  It also finds out when the tail change direction.
 */
 
//CLEAR LOG
print("\\Clear");

// CLOSE ALL OPEN IMAGES
while (nImages>0) { 
	selectImage(nImages); 
    close(); 
    close("Log");
}

//SET BATCH MODE 
setBatchMode(true);   //true or false, true if you don't want to see the images, which is faster

//START MESSAGE
print("**** STARTING THE MACRO ****");

//INPUT/OUPUT folders
inDir=getDirectory("Choose the input folder"); 
outputDir=getDirectory("And the output folder");
myList=getFileList(inDir);  //an array

//Define your measurments and settings for ROI manager
roiManager("Set Line Width", 1);
roiManager("reset");

for (j = 0 ; j < myList.length ; j++ ){
	path=inDir+myList[j];   //path to each file
	open(path);
	FileName=File.nameWithoutExtension;
	ImageID=File.name;
	print("Processing "+ImageID);
	
	//Creating a new Table of result
	Table1="Results_for_"+FileName;
	Table.create(Table1);

	//tracking the fish as a single point to find out which direction it is taking
	selectWindow(ImageID);
	run("Duplicate...", "duplicate");
	selectWindow(FileName+"-1.tif");
	rename(FileName+"_Points");
	run("Set Measurements...", "area center stack display nan redirect=None decimal=0");
	CleanNumberOfSlices=nSlices;
	print("This files has "+CleanNumberOfSlices+" frames");
	run("Temporal-Color Code", "lut=Fire start=1 end="+CleanNumberOfSlices);
	selectImage("MAX_colored");
	rename(FileName+"_TemporalProjection");
	selectImage(FileName+"_Points");
	
	//for each slice, find the coordinate of the ultimate point
	
	for (z = 0; z < CleanNumberOfSlices; z++) {
		selectImage(FileName+"_Points");
		setSlice(z+1);
		run("Analyze Particles...", "display add slice");
		Slice=getResult("Slice",nResults-1);
		XM=getResult("XM",nResults-1);
		YM=getResult("YM",nResults-1);
		IJ.renameResults("Results", "Temp");
		
		//Put the results in the final result table
		IJ.renameResults(Table1,"Results");
		setResult("Frame", z, Slice);
		setResult("Center of Mass X", z, XM);
		setResult("Center of Mass Y", z, YM);
		IJ.renameResults("Results",Table1);
		IJ.renameResults("Temp", "Results");

		//put arrows for fish movement on temporal code image
		selectImage(FileName+"_TemporalProjection");
		if(z==0){
			OldXM=XM;
			OldYM=YM;
			}
		makeArrow(OldXM, OldYM, XM, YM, "filled");
		Roi.setStrokeWidth(2);
		Roi.setStrokeColor("green");
		run("Add Selection...");
		OldXM=XM;
		OldYM=YM;
		}
		selectWindow(FileName+"_TemporalProjection");
		run("Flatten");
		saveAs("Tiff", outputDir+FileName+"_TemporalProjection.tif");
		close();
		close(FileName+"_TemporalProjection");
		selectWindow("Results");
		saveAs("Results", outputDir+FileName+"_FishTracking.csv");
		close("Results");
		roiManager("Save", outputDir+"Trace_"+ImageID+"_ROISet.zip");
		roiManager("reset");
		selectImage(FileName+"_Points");
		close();

//simplifying the image so that the fish are all aligned

NumberOfSlices=nSlices;
run("Set Measurements...", "center bounding display redirect=None decimal=3");

for (w = 0; w < NumberOfSlices; w++) {

	//first, we find the orientation of the fish and rotate it so it's aligned vertically
	selectWindow(ImageID);
	setSlice(w+1);	
	run("Oriented Bounding Box", "label="+ImageID+" show image="+ImageID);
	selectWindow(FileName+"-OBox");
	IJ.renameResults(FileName+"-OBox","Results");
	Orientation=getResult("Box.Orientation", 0);
	IJ.renameResults("Results",FileName+"-OBox");
	RotationAngle=270-Orientation;
	selectWindow(ImageID);
	setSlice(w+1);
	run("Rotate... ", "angle="+RotationAngle+" grid=1 interpolation=None slice");
	run("Options...", "iterations=1 count=1 black do=Nothing");
	run("Dilate", "slice");

	//now we find the position of the fish and translate to a common coordinate
	run("Analyze Particles...", "add slice");
	run("Measure");
	PositionX=getResult("XM", 0);
	PositionY=getResult("YM",0);
	
	//find if the fish head is up or down and rotate accordingly
	run("Duplicate...", "Duplicate");
	rename("Frame "+w);
	TranslationX=100-PositionX;
	TranslationY=100-PositionY;
	run("Translate...", "x="+TranslationX+" y="+TranslationY+" interpolation=None slice");
	run("Options...", "iterations=8 count=1 black do=Nothing");
	//erode the fish until only the head is visible and get coordinates.  Since the frames are aligned, if the head is up, its coordinate in Y will be lower than the assigned value
	
	run("Erode");
	run("Analyze Particles...", "display");
	PositionHeadX=getResult("XM", 1);
	PositionHeadY=getResult("YM", 1);
	close("Results");
	close("Frame "+w);
	selectWindow(ImageID);
	setSlice(w+1);
	
	if(PositionHeadY<100){ //100 is the assigned lower value for the head
		
		run("Rotate... ", "angle=180 grid=1 interpolation=None slice");
		run("Analyze Particles...", "add slice");
		run("Measure");
		PositionX=getResult("XM", 0);
		PositionY=getResult("YM",0);
	}

	//translate fish to common coordinate 
	
	TranslationX=100-PositionX;
	TranslationY=100-PositionY;
	selectWindow(ImageID);
	setSlice(w+1);
	run("Translate...", "x="+TranslationX+" y="+TranslationY+" interpolation=None slice");
	close("Results");
	roiManager("reset");
}
makeRectangle(0, 0, 200, 200);
run("Crop");
	//now finding the coordinates of the fish head and tail in every slice, first need to define some variables
	
		OldExtremity1X=0;
		OldExtremity1Y=0;
		OldDifference1X=0;
		OldDifference1Y=0;
		OldVector1X=0;
		OldVector1Y=0;
		BeatCounter1X=0;
		BeatCounter1Y=0;
			
	roiManager("Set Color", "green");
	roiManager("Set Line Width", 1);
	
	
	for (k = 1; k < CleanNumberOfSlices+1; k++) {
		setSlice(k);
//Geodesic diameter will find the coordinates of the furthest points in the fish, see https://imagej.net/MorphoLibJ#Geodesic_diameter
		
		run("Geodesic Diameter", "label=["+ImageID+"] distances=[Chessknight (5,7,11)] show image=["+ImageID+"] export");
		
		//getting coordinates of upper extremity (tail) of the Geodesic Diameter
		IJ.renameResults(FileName+"-GeodDiameters","Results");
		Extremity1X=getResult("Extremity1.X",nResults-1);
		Extremity1Y=getResult("Extremity1.Y",nResults-1);
		IJ.renameResults("Results", FileName+"-GeodDiameters");
		
		SliceNumber=k;
		m=k-1;
		IJ.renameResults(Table1,"Results");
	
	//Put the results in the result table	
		setResult("Frame", m, k);
		setResult("Tail X", m, Extremity1X);
		setResult("Tail Y", m, Extremity1Y);
		
//finding if how many times the fish beats its tail: counting as 1 when tail changes direction in X, otherwise it's 0
		Difference1X=Extremity1X-OldExtremity1X;
			if(Difference1X>0){
				Vector1X=1;
			}
			else{
				Vector1X=-1;
			}
			
	//Disregard the first frame as there is no previous frame to compare
			if(k==1){
				Beat1X="N/A";
				}
	//now going to the other frames		
			//counting beats for tail in X
			if(k>1){
				if(Vector1X+OldVector1X==0){
						Beat1X=1;
						BeatCounter1X=BeatCounter1X+1;
						}
				else{
				Beat1X=0;
				}		
			}
		setResult("Beat lower extremity in X", m, Beat1X);
					
		IJ.renameResults("Results", Table1);
		OldVector1X=Vector1X;
		OldExtremity1X=Extremity1X;
		OldDifference1X=Difference1X;
		}

//saving image
selectWindow(ImageID);
saveAs("Tiff", outputDir+ImageID);

//saving table of results
selectWindow(Table1);
saveAs("Results", outputDir+Table1+".csv");

//saving log
print("This fish beat its tail "+BeatCounter1X+" times in "+CleanNumberOfSlices+" analysed frames");
selectWindow("Log");
saveAs("Text", outputDir+FileName+"_Log.txt");
print("***** Macro done *****");

//Tidying up
roiManager("reset");
close();
close(Table1+".csv");
close("Log");
close("free-GeodDiameters");

}



close("*");

print("***** Macro done *****");