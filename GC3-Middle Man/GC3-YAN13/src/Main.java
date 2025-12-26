import javax.swing.*;
import java.awt.*;
import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;

 class PncYanValidationSwing {

    public static void main(String[] args) {
        // Create main frame
        JFrame frame = new JFrame("PNC-YAN Validation");
        frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        frame.setSize(400, 250);
        frame.setLayout(new GridBagLayout());
        GridBagConstraints gbc = new GridBagConstraints();
        gbc.insets = new Insets(10, 10, 10, 10);
        gbc.fill = GridBagConstraints.HORIZONTAL;

        // PNC label and text field
        JLabel pncLabel = new JLabel("Enter PNC:");
        JTextField pncField = new JTextField(20);

        gbc.gridx = 0; gbc.gridy = 0;
        frame.add(pncLabel, gbc);
        gbc.gridx = 1; gbc.gridy = 0;
        frame.add(pncField, gbc);

        // YAN label and text field
        JLabel yanLabel = new JLabel("Enter YAN:");
        JTextField yanField = new JTextField(20);

        gbc.gridx = 0; gbc.gridy = 1;
        frame.add(yanLabel, gbc);
        gbc.gridx = 1; gbc.gridy = 1;
        frame.add(yanField, gbc);

        // Result label
        JLabel resultLabel = new JLabel("");
        gbc.gridx = 0; gbc.gridy = 3; gbc.gridwidth = 2;
        frame.add(resultLabel, gbc);

        // Validate button
        JButton validateButton = new JButton("Validate");
        gbc.gridx = 0; gbc.gridy = 2; gbc.gridwidth = 2;
        frame.add(validateButton, gbc);

        // Button action
        validateButton.addActionListener(e -> {
            String inputPNC = pncField.getText().trim();
            String inputYAN = yanField.getText().trim();
            String filePath = "Download_20250831-121429 1.csv";
            boolean found = false;

            try (BufferedReader br = new BufferedReader(new FileReader(filePath))) {
                String line;
                br.readLine(); // skip header

                while ((line = br.readLine()) != null) {
                    String[] values = line.split(",");
                    if (values.length < 8) continue;

                    String csvPNC = values[1].trim(); // column 1 = PNC
                    String csvYAN = values[7].trim(); // column 7 = YAN

                    if (csvPNC.equalsIgnoreCase(inputPNC)) {
                        found = true;
                        if (csvYAN.equalsIgnoreCase(inputYAN)) {
                            resultLabel.setText("✅ Validation successful: YAN matches PNC!");
                            resultLabel.setForeground(Color.GREEN);
                        } else {
                            resultLabel.setText("❌ Validation failed! Expected YAN: " + csvYAN);
                            resultLabel.setForeground(Color.RED);
                        }
                        break;
                    }
                }

                if (!found) {
                    resultLabel.setText("❌ No matching PNC found in CSV.");
                    resultLabel.setForeground(Color.RED);
                }

            } catch (IOException ex) {
                resultLabel.setText("Error reading CSV: " + ex.getMessage());
                resultLabel.setForeground(Color.RED);
            }
        });

        frame.setVisible(true);
    }
}
