package example.testgrader;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;

import android.net.Uri;
import android.os.Bundle;
import android.app.Activity;
import android.content.Intent;
import android.util.Log;
import android.view.Menu;

public class MainActivity extends Activity {
//	static Runnable r = new Runnable() {
//
//		@Override
//		public void run() {
//		    URL url;
//		    try {
//		        url = new URL("http://rva.cs.illinois.edu/");
//
//		        HttpURLConnection urlConnection = (HttpURLConnection) url
//		                .openConnection();
//
//		        InputStream in = urlConnection.getInputStream();
//
//		        InputStreamReader isw = new InputStreamReader(in);
//
//		        int data = isw.read();
//		        while (data != -1) {
//		            char current = (char) data;
//		            data = isw.read();
//		            System.out.print(current);
//		        }
//		    } catch (Exception e) {
//		        // TODO Auto-generated catch block
//		        e.printStackTrace();
//		    }				
//		}
//		
//	};
	

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.activity_main);

		Intent browserIntent = new Intent(Intent.ACTION_VIEW,
				Uri.parse("http://illinois.edu/"));
		browserIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
		startActivity(browserIntent);

		//Thread t = new Thread(r);
		//t.start();
		System.out.println("Hey!!!!");
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		// Inflate the menu; this adds items to the action bar if it is present.
		getMenuInflater().inflate(R.menu.main, menu);
		return true;
	}

}
