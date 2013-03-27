package example.testgrader.test;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.PrintStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.util.Enumeration;
import java.util.List;
import java.util.concurrent.CountDownLatch;

import example.testgrader.MainActivity;

import junit.framework.TestCase;
import junit.framework.TestFailure;
import junit.framework.TestResult;

import android.app.ActivityManager;
import android.app.Instrumentation;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.test.AndroidTestRunner;
import android.test.InstrumentationTestRunner;
import junit.textui.ResultPrinter;

public class MyRunner extends InstrumentationTestRunner {

	GradingAndroidTestRunner androidRunner;
	final String assignmentName = "Assignment1";
	final String[] partIDs = new String[] { "hvSBXixt" };
	final String[] partNames = new String[] { "Part1" };
	final String timeKey = assignmentName + "time";
	final int maxSubmissionIntervalSec = 30;

	// static Runnable r;
	// static String resultToSubmit;
	// static String submissionResult;
	// static String resultFilePath;
	// static CountDownLatch finishLatch;

	@Override
	public void onCreate(Bundle arguments) {
		// System.out.println("On Create: HEYYYYY!");
		super.onCreate(arguments);

	}

	@Override
	public void onStart() {
		System.out.println("On Start: HEYYYYY!");
		// PrintStream stream;
		// try {
		// stream = new
		// PrintStream("/Users/samira_tasharofi/Documents/result.txt");
		// ResultPrinter submitPrinter = new ResultPrinter(System.out);
		// androidRunner.addTestListener(submitPrinter);
		//
		//
		// } catch (FileNotFoundException e) {
		// // TODO Auto-generated catch block
		// e.printStackTrace();
		// }

		super.onStart();
	}

	@Override
	public void start() {

		super.start();

	}

	protected AndroidTestRunner getAndroidTestRunner() {
		// System.out.println("Create RUNNER! ");
		androidRunner = new GradingAndroidTestRunner();
		// ResultPrinter submitPrinter;
		// try {
		// submitPrinter = new ResultPrinter(new PrintStream("result.txt"));
		// androidRunner.addTestListener(submitPrinter);
		//
		// } catch (FileNotFoundException e) {
		// // TODO Auto-generated catch block
		// e.printStackTrace();
		// }

		return androidRunner;
	}

	@Override
	public void finish(int resultCode, Bundle results) {

		List<TestCase> testCases = androidRunner.getTestCases();

		for (TestCase test : testCases) {
			System.out.println("****** TEST CASE: " + test.getName());
		}

		TestResult testResult = androidRunner.getTestResult();

		System.out.println("****** FAILED COUNT: " + testResult.failureCount());
		System.out.println("****** PASSED COUNT: "
				+ (testResult.runCount() - testResult.failureCount()));

		Enumeration<TestFailure> failures = testResult.failures();

		while (failures.hasMoreElements()) {
			TestFailure failure = failures.nextElement();
			System.out.println("****** FAILED TEST: " + failure.failedTest());

		}
		System.out.println(" ******* "
				+ results.getString(Instrumentation.REPORT_KEY_STREAMRESULT));

		int currResult = testResult.runCount() - testResult.failureCount();

		Context runnerContext = androidRunner.getContext();

		if (runnerContext != null) {
			String prevResult = runnerContext.getSharedPreferences(
					"TestResults", 0).getString(assignmentName, "0");
			long prevTimeSec = runnerContext.getSharedPreferences(
					"TestResults", 0).getLong(timeKey, 0);
			System.out.println(" **************** Prev RESULT: " + prevResult);
			System.out.println(" **************** Prev TIME: " + prevTimeSec);

			long currTimeSec = System.currentTimeMillis() / 1000;
			System.out.println(" **************** Cur TIME: " + currTimeSec);

			
			String submissionResult = "";

			if (Integer.parseInt(prevResult) < currResult
					|| (currTimeSec - prevTimeSec) > maxSubmissionIntervalSec) {
				String resultToSubmit = String.valueOf(currResult);
				Submitter submitter = new Submitter();
				submissionResult = submitter.submit(resultToSubmit);
				runnerContext.getSharedPreferences("TestResults", 0).edit()
						.putString(assignmentName, resultToSubmit).commit();
				runnerContext.getSharedPreferences("TestResults", 0).edit()
						.putLong(timeKey, currTimeSec).commit();
				
				browserPOST(runnerContext, submissionResult);


			}
			else if(Integer.parseInt(prevResult) > currResult){
				submissionResult = "No need to resbmit; your new submission score is lower than previous submissions";
				browserPOST(runnerContext, submissionResult);

			}
			

		} else {
			System.err.println("The context is null .... ");
		}

		super.finish(resultCode, results);
	}

	private void browserPOST(Context context, String submissionResult) {
		//
		// Runnable r = new Runnable() {
		// @Override
		// public void run() {
		//
		// Intent browserIntent = new Intent(Intent.ACTION_VIEW,
		// Uri.parse("http://www.google.com"));
		// browserIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
		// context.startActivity(browserIntent);
		// }
		// };
		// Thread t = new Thread(r);
		// t.start();
		// try {
		// t.join();
		// } catch (InterruptedException e) {
		// // TODO Auto-generated catch block
		// e.printStackTrace();
		// }

		try {
			String submissionHtmlFile = "submission.html";
			FileOutputStream file = context.openFileOutput(submissionHtmlFile,
					context.MODE_WORLD_READABLE);

			System.out.println(context.getFilesDir());
			System.out.println(context.getFileStreamPath(submissionHtmlFile)
					.getAbsolutePath());

			String content = String.format("<html><head><title>Submission Results</title></head><body>%s</body></html>", submissionResult);

			file.write(content.getBytes());
			file.close();

			Intent i = new Intent();
			// MUST instantiate android browser, otherwise it won't work (it
			// won't find an activity to satisfy intent)
			i.setComponent(new ComponentName("com.android.browser",
					"com.android.browser.BrowserActivity"));
			i.setAction(Intent.ACTION_VIEW);

			// String html =
			// "<html><head><title>Submission Results</title></head><body>Check your Connection/ Congrats!!! Congrats!!</body></html>";
			// // May work without url encoding, but I think is advisable
			// // URLEncoder.encode replace space with "+", must replace again
			// with
			// // %20
			// String dataUri = "data:text/html," +
			// html.replaceAll("\\+","%20");

			i.setData(Uri.fromFile(context.getFileStreamPath(submissionHtmlFile)));// .parse(dataUri));

			// need to set new task flag !?
			i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
			
			
			context.startActivity(i);

		} catch (Exception e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
	}

}
