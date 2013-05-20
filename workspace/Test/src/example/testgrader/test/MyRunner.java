package example.testgrader.test;

import java.io.BufferedReader;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URLEncoder;
import java.util.Enumeration;
import java.util.List;

import junit.framework.TestCase;
import junit.framework.TestFailure;
import junit.framework.TestResult;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.test.AndroidTestRunner;
import android.test.InstrumentationTestRunner;

public class MyRunner extends InstrumentationTestRunner {

	GradingAndroidTestRunner androidRunner;
	final String assignmentName = "Assignment1";
	final String[] partIDs = new String[] { "hvSBXixt" };
	//new String[] { "hvSBXixttt" }; // for testing wrong assignment
	final int partIndex = 0;
	final String[] partNames = new String[] { "Part1" };
	final String timeKey = assignmentName + "time";
	final int maxSubmissionIntervalSec = 5;// 30;
	final String submissionInfoFile = "submissionInfo.txt";

	@Override
	public void onCreate(Bundle arguments) {
		super.onCreate(arguments);
	}

	@Override
	public void onStart() {
		super.onStart();
	}

	@Override
	public void start() {
		super.start();
	}

	protected AndroidTestRunner getAndroidTestRunner() {
		androidRunner = new GradingAndroidTestRunner();
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

		int currResult = testResult.runCount() - testResult.failureCount();
		int prefectScore = testResult.runCount();

		Context runnerContext = androidRunner.getContext();
		String submissionResult = "";

		if (runnerContext != null) {

			Submitter submitter = new Submitter(assignmentName, partNames,
					partIDs);

			String[] credential = readCredential(runnerContext);
			if (credential.length > 1) {
				String[] challenge = submitter.getChallenge(partIndex,
						credential);

				if (challenge != null) {

					String prevResult = runnerContext.getSharedPreferences(
							"TestResults", 0).getString(
							credential[0] + assignmentName, "-1");

					long prevTimeSec = runnerContext.getSharedPreferences(
							"TestResults", 0).getLong(credential[0] + timeKey,
							0);

					long currTimeSec = System.currentTimeMillis() / 1000;

					/*
					 * Only submits the answer if the current score is greater
					 * than the last submitted score or the scores are the same
					 * and difference between current submission time and
					 * previous submission is more than the threshold.
					 */
					submissionResult += String
							.format("<p>Submission feedback for user %s and assignment %s - part %s: </p>",
									credential[0], assignmentName, partNames[partIndex]);

					if (Integer.parseInt(prevResult) < currResult
							|| (Integer.parseInt(prevResult) == currResult &&
							(currTimeSec - prevTimeSec) > maxSubmissionIntervalSec) ){

						submissionResult += String.format(
								"<p> Your score is %s out of %s.</p>",
								currResult, prefectScore);

						String resultToSubmit = String.valueOf(currResult);

						if (credential.length > 1) {
							submissionResult += submitter.submit(
									resultToSubmit, partIndex, credential,
									challenge);

							runnerContext
									.getSharedPreferences("TestResults", 0)
									.edit()
									.putString(credential[0] + assignmentName,
											resultToSubmit).commit();
							runnerContext
									.getSharedPreferences("TestResults", 0)
									.edit()
									.putLong(credential[0] + timeKey,
											currTimeSec).commit();

						}

					} else if (Integer.parseInt(prevResult) >= currResult) {
						System.out.println(" No need to resubmit");
						submissionResult += String
								.format("<p>Your new submission score is %s out of %s and the maximum score of your previous submissions is %s.</p>",
										currResult, prefectScore, prevResult);
						submissionResult += "<p>No need to resbmit; your new submission score is is not higher than the previous submissions score.</p>";
					}
				} else {
					submissionResult += String.format(
							Messages.GETTING_CHALLENGE_ERROR_TEMPLATE,
							assignmentName,partNames[partIndex]);
				}
			} else {
				// There is an error in parsing email and password or opening
				// the submission info file.
				submissionResult += credential[0];
			}

		} else {
			submissionResult += Messages.NULL_CONTEXT;
			System.err.println("The context is null .... ");
		}

		System.out.println(submissionResult);
		if (!submissionResult.equals(""))
			showTheResultsInBrowser(runnerContext, submissionResult);

		super.finish(resultCode, results);
	}

	private String[] readCredential(Context runnerContext) {
		String[] credential = new String[2];

		try {
			System.out.println(runnerContext.getAssets().list("."));
			BufferedReader submissionInfoReader = new BufferedReader(
					new InputStreamReader(runnerContext.getAssets().open(
							submissionInfoFile)));
			String line;
			while ((line = submissionInfoReader.readLine()) != null) {
				line = line.trim().replace(" ", "");
				if (line.contains("Email=") && credential[0] == null) {
					credential[0] = line.replace("Email=", "").trim();
				} else if (line.contains("Password=") && credential[1] == null) {
					credential[1] = line.replace("Password=", "").trim();
				}
			}
			if (credential[0] == null || credential[1] == null
					|| credential[0].length() == 0
					|| credential[1].length() == 0) {
				return new String[] { Messages.ILL_FORMATTED_INFOFILE };
			}

		} catch (IOException e) {
			return new String[] { Messages.MISSING_SUBMISSIONINFOFILE };
		}
		return credential;
	}

	private void showTheResultsInBrowser(Context context,
			String submissionResult) {
		String content = String
				.format("<html><head><title>Submission Results</title></head><body>%s</body></html>",
						submissionResult);

		Intent i = new Intent();
		i.setComponent(new ComponentName("com.android.browser",
				"com.android.browser.BrowserActivity"));
		i.setAction(Intent.ACTION_VIEW);

		try {

			String baseName = "SubmissionResult";
			String htmlFileName = nextUniqueBaseName(context, baseName);// "submission.html";

			FileOutputStream htmlWriter = context.openFileOutput(htmlFileName,
					context.MODE_WORLD_READABLE);
			System.out.println(context.getFilesDir());
			htmlWriter.write(content.getBytes());
			htmlWriter.close();
			i.setData(Uri.fromFile(context.getFileStreamPath(htmlFileName)));

			// need to set new task flag !?
			i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
			context.startActivity(i);

		} catch (Exception e) {
			e.printStackTrace();
			// May work without url encoding, but I think is advisable
			// URLEncoder.encode replace space with "+", must replace again with
			// %20
			String dataUri = "data:text/html,"
					+ URLEncoder.encode(content).replaceAll("\\+", "%20");
			i.setData(Uri.parse(dataUri));

			// need to set new task flag !?
			i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);

			context.startActivity(i);
		}
	}

	private String nextUniqueBaseName(Context context, String base) {
		int max = 0;
		final int baseLen = base.length();

		for (String name : context.getFilesDir().list()) {
			if (!name.startsWith(base))
				continue;
			max = Math.max(max, extractPositiveInteger(name, baseLen));
			context.deleteFile(name);
		}
		return base + (max + 1);
	}

	private int extractPositiveInteger(final String line, int index) {
		final int lineLen = line != null ? line.length() : 0;
		int val = 0;
		while (index >= 0 && index < lineLen) {
			final char c = line.charAt(index++);
			// Character.isDigit() is too lenient, we only want 0..9
			if (c >= '0' && c <= '9')
				val = val * 10 + (c - '0');
			else
				break;
		}
		return val;
	}

}
