import java.util.Scanner;

public class MainAI {

    public static void main (String[] args){
        Scanner myInput = new Scanner(System.in);

        System.out.println("Hello, what's your name?");
        String myname = myInput.nextLine();
        System.out.println("hi " + myname + ", It's simon your bestie");

        if (myname=="Jack") then {
            System.out.println("Hi" + myname "I've not chatted with you for a long time, how are you>");
            System.out.println("How's the temperature there?");
            float TemperatureCity = myInput.nextFloat();

            System.out.println("it's not too bad in TW!")
        }
        else (myname == "Yvonne") {
            System.out.println("How's taiwan and how's the weather there? How many degrees is it?");

            float YvTemp = myInput.nextFloat();

            if (YvTemp <= 0.0) System.out.println("Wow that's really cold and unusual");
            else System.out.println("Got nothing on us y'all")

        }
    }
        myInput.close();
    }

}