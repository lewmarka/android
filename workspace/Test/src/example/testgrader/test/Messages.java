package example.testgrader.test;

public class Messages {

	public static final String MISSING_SUBMISSIONINFOFILE = "<p>Error in reading the \"submissionInfo.txt\" file. "
			+ "Please make sure that the \"submissionInfo.txt\" exists in the \"assets\" folder of your application</p>";

	public static final String GETTING_CHALLENGE_ERROR_TEMPLATE = 
			"<p>Error in getting the challenge for assignment %s - part %s. "+
	"Make sure that you have internet connection and you are submitting a valid assignment.</p>";

	public static final String INCORRECT_EMAIL_PASSWORD = 
			"<p>Submission Error! The email or the password is incorrect. Note that the pasword is a 10 character alphanumeric string displayed on the top of the Assignments page.</p>"
			+ "<p>Please correct them in \"submissionInfo.txt\" file which is in \"assets\" folder and resubmit.</p>";
	
	public static final String ILL_FORMATTED_INFOFILE = 
			"<p> Error in parsing the \"submissionInfo.txt\" file in the \"assets\" folder of your application. " +
			"The file is in a wrong format. "+
			"Please make sure that in the first line you have specified your email in front of \"Email:\" "+
			"and in the second line you have specified your password in front of \"Password:\".</p>";
	
	public static final String NULL_CONTEXT = "<p>Unexpected exception happened. Please try again.</p>";

}
