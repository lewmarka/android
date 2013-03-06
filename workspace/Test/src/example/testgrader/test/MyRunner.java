package example.testgrader.test;
import java.util.Enumeration;
import java.util.List;

import junit.framework.TestCase;
import junit.framework.TestFailure;
import junit.framework.TestResult;

import android.os.Bundle;
import android.test.AndroidTestRunner;
import android.test.InstrumentationTestRunner;


public class MyRunner extends InstrumentationTestRunner {
	
	
	AndroidTestRunner androidRunner;
	
	@Override
	 public void onCreate(Bundle arguments) {
		//System.out.println("On Create: HEYYYYY!");
		super.onCreate(arguments);
		
	}
	@Override
	public void onStart(){
		//System.out.println("On Start: HEYYYYY!");
		
		super.onStart();
	}
	
	
    protected AndroidTestRunner getAndroidTestRunner() {
		//System.out.println("Create RUNNER! ");

    	androidRunner = new AndroidTestRunner();
    	return androidRunner;
    }

	@Override
    public void finish(int resultCode, Bundle results) {
		
		List<TestCase> testCases = androidRunner.getTestCases();
		
		
		for (TestCase test: testCases){
			System.out.println("****** TEST CASE: "+ test.getName());			
		}
		
		TestResult testResult = androidRunner.getTestResult();
		
		System.out.println("****** FAILED COUNT: "+testResult.failureCount());
		System.out.println("****** PASSED COUNT: "+(testResult.runCount()-testResult.failureCount()));
		
		Enumeration<TestFailure> failures = testResult.failures();
		
		while(failures.hasMoreElements()){
			TestFailure failure = failures.nextElement();
			System.out.println("****** FAILED TEST: "+ failure.failedTest());

		}
		
		//String result = results.getString(Instrumentation.REPORT_KEY_STREAMRESULT);
		
		//System.out.println("FINISH: HEYYYYY! "+ result + results.size());
		
		
		super.finish(resultCode, results);
    }


}
