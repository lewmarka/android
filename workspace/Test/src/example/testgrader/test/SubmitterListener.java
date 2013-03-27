package example.testgrader.test;

import junit.framework.AssertionFailedError;
import junit.framework.Test;
import junit.framework.TestListener;


public class SubmitterListener implements TestListener {

	@Override
	public void addError(Test test, Throwable t) {
		// TODO Auto-generated method stub

	}

	@Override
	public void addFailure(Test test, AssertionFailedError t) {
		// TODO Auto-generated method stub

	}

	@Override
	public void endTest(Test test) {
		
		//JOptionPane.showMessageDialog(null,st);
		// TODO Auto-generated method stub

	}

	@Override
	public void startTest(Test test) {
		// TODO Auto-generated method stub

	}

}
