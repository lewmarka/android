package example.testgrader.test;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.net.URL;
import java.net.URLConnection;
import java.net.URLEncoder;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.List;
import java.util.concurrent.CountDownLatch;

public class Submitter {

	String[] partNames;
	String[] partIDs;
	String assignmentName;

	public Submitter(String assignmentName, String[] partNames, String[] partIDs) {
		this.assignmentName = assignmentName;
		this.partNames = partNames;
		this.partIDs = partIDs;
	}

	public String[] getChallenge(int partIndex, String[] credential){
		
		String error = null;
//		List<Integer> submitParts = new ArrayList<Integer>();
//		if (partIndex == partIDs.length) {
//			for (int i = 0; i < partIDs.length; i++) {
//				submitParts.add(new Integer(i));
//			}
//		} else {
//			submitParts.add(new Integer(partIndex));
//		}
		String login = credential[0];

//		for (Integer part : submitParts) {
			// Get Challenge
			String[] loginChSignature = getChallenge(login, partIndex);
			if (loginChSignature == null) {
				error = String
						.format("<p>Error in getting the challenge for user %s and part %s. Make sure that the email and the specified assignment part is correct.</p>",
								login, partIndex);
				System.out.println(error);
			}
			if (loginChSignature != null)
			System.out.println("Getting the challenge: "+loginChSignature[0]+loginChSignature[1]);
//		}
		return loginChSignature;
	}
	public String submit(String testResult, int partIndex, String[] credential, String[] loginChSignature) {

		String submissionResult = "";
		String login = credential[0];
		String password = credential[1];

		System.out.print("\n== Connecting to coursera ... ");

		// Setup the list of parts and sections needed to be submitted
//		List<Integer> submitParts = new ArrayList<Integer>();
//		if (partIndex == partIDs.length) {
//			for (int i = 0; i < partIDs.length; i++) {
//				submitParts.add(new Integer(i));
//			}
//		} else {
//			submitParts.add(new Integer(partIndex));
//		}

		int part = partIndex;
//		for (Integer part : submitParts) {
			// Get Challenge
//			String[] loginChSignature = getChallenge(login, part);
//			if (loginChSignature == null) {
//				submissionResult += String
//						.format("<p>Error in getting the challenge for user %s and part %s. Make sure that the email and the specified assignment part is correct.</p>",
//								login, part);
//				return submissionResult;
//			}

			login = loginChSignature[0];
			String ch = loginChSignature[1];
			String signature = loginChSignature[2];
			String ch_aux = loginChSignature[3];


			// Attempt Submission with Challenge
			String ch_resp = challengeResponse(login, password, ch);
			String response = submitSolution(login, ch_resp, part,
					testResult, /* source(part) */"", signature);

			// Null response may receive if the answer is incorrect and there is no feedback for that
			if (response == null) {
				response = "Your solution does not match with the expected solution. Please try again.";
			}
			if (response
					.trim()
					.equals("Exception: We could not verify your username / password, please try again. (Note that your password is case-sensitive.)")) {
				//submissionResult += "<p>The password is incorrect. Note that the pasword is a 10 character alphanumeric string displayed on the top of the Assignments page.</p>";
				//submissionResult += "<p>Please correct it in \"submissionInfo.txt\" file which is in \"assets\" folder and resubmit.</p>";
				return Messages.INCORRECT_EMAIL_PASSWORD;
			}
			
			submissionResult += String.format(
					"<p>Submitted successfully.</p>")
					+ "\n";

			submissionResult += String.format("<p>Feedback: %s</p>",response);
			submissionResult += "<p>================= </p>";

//		}
		return submissionResult;
	}

	private List<List<String>> sources() {
		List<List<String>> srcs = new ArrayList<List<String>>();
		List<String> tmp;

		// Java.
		tmp = new ArrayList<String>(1);
		tmp.add("./src/submitter/Base64.java");
		srcs.add(tmp);

		return srcs;
	}

	private String challenge_url() {
		return "https://class.coursera.org/androidapps101-001/assignment/challenge";
	}

	private String submit_url() {
		return "https://class.coursera.org/androidapps101-001/assignment/submit";
	}

	// ========================= CHALLENGE HELPERS =========================

	private String source(int partId) {
		StringBuffer src = new StringBuffer();
		// List<List<String>> src_files = sources();
		// if (partId < src_files.size()) {
		// List<String> flist = src_files.get(partId);
		// for (String fname : flist) {
		// try {
		// BufferedReader reader = new BufferedReader(new FileReader(
		// fname));
		// String line;
		// while ((line = reader.readLine()) != null) {
		// src.append(line);
		// }
		// reader.close();
		// src.append("||||||||");
		// } catch (IOException e) {
		// System.err.println(String.format(
		// "!! Error reading file '%s': %s", fname,
		// e.getMessage()));
		// return src.toString();
		// }
		// }
		// }
		src.append("");
		return src.toString();
	}

	// Returns [email,ch,signature]
	private String[] getChallenge(String email, int partId) {
		String[] results = new String[4];
		try {
			URL url = new URL(challenge_url());
			URLConnection connection = url.openConnection();
			connection.setDoOutput(true);
			OutputStreamWriter out = new OutputStreamWriter(
					connection.getOutputStream());
			// url encode e-mail
			out.write("email_address=" + URLEncoder.encode(email, "UTF-8"));
			out.write("&assignment_part_sid=" + partIDs[partId]);
			out.write("&response_encoding=delim");
			out.close();
			BufferedReader in = new BufferedReader(new InputStreamReader(
					connection.getInputStream()));
			StringBuffer sb = new StringBuffer();
			String line;
			while ((line = in.readLine()) != null) {
				sb.append(line + "\n");
			}
			String str = sb.toString();
			in.close();

			String[] splits = str.split("\\|");

			if (splits.length < 8) {
				System.err.println("!! Error getting challenge from server.");
				for (String string : results) {
					System.err.println(string);
				}
				return null;
			} else {
				results[0] = splits[2]; // email
				results[1] = splits[4]; // ch
				results[2] = splits[6]; // signature
				if (splits.length == 9) { // if there's a challenge, use it
					results[3] = splits[8];
				} else {
					results[3] = null;
				}
			}
		} catch (Exception e) {
			System.err.println("Error getting challenge from server: "
					+ e.getMessage());
			return null;
		}
		return results;
	}

	private String submitSolution(String email, String ch_resp, int part,
			String output, String source, String state) {
		String str = null;
		try {
			StringBuffer post = new StringBuffer();
			post.append("assignment_part_sid="
					+ URLEncoder.encode(partIDs[part], "UTF-8"));
			post.append("&email_address=" + URLEncoder.encode(email, "UTF-8"));
			post.append("&submission="
					+ URLEncoder.encode(base64encode(output), "UTF-8"));
			post.append("&submission_aux="
					+ URLEncoder.encode(base64encode(source), "UTF-8"));
			post.append("&challenge_response="
					+ URLEncoder.encode(ch_resp, "UTF-8"));
			post.append("&state=" + URLEncoder.encode(state, "UTF-8"));

			URL url = new URL(submit_url());
			URLConnection connection = url.openConnection();
			connection.setDoOutput(true);
			OutputStreamWriter out = new OutputStreamWriter(
					connection.getOutputStream());
			out.write(post.toString());
			out.close();

			BufferedReader in = new BufferedReader(new InputStreamReader(
					connection.getInputStream()));

			String line = "";
			str = "";
			while ((line = in.readLine()) != null) {
				str += line + " ";
			}
			in.close();

		} catch (Exception e) {
			System.err.println("!! Error submittion solution: "
					+ e.getMessage());
			return null;
		}
		return str;
	}


	private String challengeResponse(String email, String passwd,
			String challenge) {
		MessageDigest md = null;
		try {
			md = MessageDigest.getInstance("SHA-1");
		} catch (NoSuchAlgorithmException e) {
			System.err.println("No such hashing algorithm: " + e.getMessage());
		}
		try {
			String message = challenge + passwd;
			md.update(message.getBytes("US-ASCII"));
			byte[] byteDigest = md.digest();
			StringBuffer buf = new StringBuffer();
			for (byte b : byteDigest) {
				buf.append(String.format("%02x", b));
			}
			return buf.toString();
		} catch (Exception e) {
			System.err.println("Error generating challenge response: "
					+ e.getMessage());
		}
		return null;
	}

	public String base64encode(String str) {
		Base64 base = new Base64();
		byte[] strBytes = str.getBytes();
		byte[] encBytes = base.encode(strBytes);
		String encoded = new String(encBytes);
		return encoded;
	}
}
