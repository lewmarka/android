package example.testgrader.test;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.lang.reflect.Field;
import java.util.Enumeration;
import java.util.List;

import junit.framework.TestCase;
import junit.framework.TestFailure;
import junit.framework.TestResult;

import android.app.Instrumentation;
import android.content.Context;
import android.content.res.AssetManager;
import android.os.Bundle;
import android.os.Environment;
import android.test.AndroidTestRunner;
import android.test.InstrumentationTestRunner;


public class MyRunner extends InstrumentationTestRunner {
	
	
//	InstrumentationTestRunner runner;
	
	AndroidTestRunner androidRunner;
	
	@Override
	 public void onCreate(Bundle arguments) {
		
//		runner = new InstrumentationTestRunner();
//		runner.onCreate(arguments);
//		
		System.out.println("On Create: HEYYYYY!");
		
		
		super.onCreate(arguments);
		
	}
	@Override
	public void onStart(){
		System.out.println("On Start: HEYYYYY!");
		
		super.onStart();

//		runner.onStart();
//		Field f;
//		try {
//			f = super.getClass().getDeclaredField("mTestRunner");
//			f.setAccessible(true);
//			AndroidTestRunner androidTestRuner = (AndroidTestRunner) f.get(super.); //IllegalAccessException
//			System.out.println("RESULTS: HEYYYYY!"+ androidTestRuner.getTestResult().failureCount());
//
//		} catch (NoSuchFieldException e) {
//			// TODO Auto-generated catch block
//			e.printStackTrace();
//		} //NoSuchFieldException
// 		catch (IllegalAccessException e) {
//			// TODO Auto-generated catch block
//			e.printStackTrace();
//		}
	}
	
	
    protected AndroidTestRunner getAndroidTestRunner() {
		System.out.println("Create RUNNER! ");

    	androidRunner = new AndroidTestRunner();
    	return androidRunner;
    }

	@Override
    public void finish(int resultCode, Bundle results) {
		
		List<TestCase> testCases = androidRunner.getTestCases();
		
//		String path = "/Users/samira_tasharofi/Documents/workspace-coursera/Test/";
//		//final File dir = new File(Environment.getRootDirectory() + path);
//		//dir.mkdirs();
//		
//		//File dir = Environment.getExternalStorageDirectory();
//		dir.mkdirs();
//		
//		File resultFile = new File(path+"result2.txt");
//		try {
//			resultFile.createNewFile();
//		} catch (IOException e1) {
//			// TODO Auto-generated catch block
//			e1.printStackTrace();
//		}
//		
//		System.out.println(resultFile.getAbsolutePath());
//		
//		
//		try {
//			FileWriter writer = new  FileWriter(resultFile);
		
		for (TestCase test: testCases){
			System.out.println("****** TEST CASE: "+ test.getName());
			//writer.write("****** TEST CASE: "+ test.getName()+"\n");
			
		}
		
		TestResult testResult = androidRunner.getTestResult();
		
		System.out.println("****** FAILED COUNT: "+testResult.failureCount());
		//writer.write("****** FAILED COUNT: "+testResult.failureCount()+"\n");
		System.out.println("****** PASSED COUNT: "+(testResult.runCount()-testResult.failureCount()));
		//writer.write("****** PASSED COUNT: "+(testResult.runCount()-testResult.failureCount())+"\n");
		
		Enumeration<TestFailure> failures = testResult.failures();
		
		while(failures.hasMoreElements()){
			TestFailure failure = failures.nextElement();
			System.out.println("****** FAILED Test: "+ failure.failedTest());
			//writer.write("****** FAILED Test: "+ failure.failedTest()+"\n");

		}
		
//		writer.close();
//		
//		} catch (IOException e) {
//			// TODO Auto-generated catch block
//			e.printStackTrace();
//		}
		
		
		String result = results.getString(Instrumentation.REPORT_KEY_STREAMRESULT);
		
		//System.out.println("FINISH: HEYYYYY! "+ result + results.size());
		
		
		super.finish(resultCode, results);
		//runner.finish(resultCode, results);


    }


}
