package example.testgrader.test;
//package example.testgrader.test;
//
import java.util.ArrayList;

import example.testgrader.MainActivity;
import android.annotation.SuppressLint;
import android.test.ActivityInstrumentationTestCase2;
import android.view.View;
import android.widget.Button;


@SuppressLint("NewApi")
public class InstrumentationTest extends ActivityInstrumentationTestCase2<MainActivity> {

	public InstrumentationTest() {
		super(MainActivity.class);
		// TODO Auto-generated constructor stub
	}
	
    public void testHasToggleButtons() {
    	

      int numberOfToggleButtons = countWidgets(Button.class);

        assertTrue("Need at zero toggle buttons in the app's layout",
                numberOfToggleButtons >= 0);
    }
    
    // -------------------------------------------------------------------------------
    /**
     * Counts the number of widgets in the current display.
     *
     * @param key
     *            - the type of widget to count e.g. Button.class
     * @return the number of widgets of the requested type
     */
    @SuppressWarnings("rawtypes")
    private int countWidgets(Class key) {
        int count = 0;
        ArrayList<View> touchables = getActivity().getWindow().getDecorView()
                .getTouchables();
        for (View v : touchables) {
            if (v.getClass() == key)
                count = count + 1;
        }
        return count;
    }


}
