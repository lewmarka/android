package example.testgrader.test;

import junit.framework.TestListener;
import android.content.Context;
import android.test.AndroidTestRunner;

public class GradingAndroidTestRunner extends AndroidTestRunner {
	
	private Context context;
	
	public void setContext(Context context){
		this.context = context;
		super.setContext(context);		
	}
	
	public Context getContext() {
		return context;
	}
	
	public void addTestListener(TestListener testListener){
		
		super.addTestListener(testListener);
		System.out.println(testListener);
		
	}

}
