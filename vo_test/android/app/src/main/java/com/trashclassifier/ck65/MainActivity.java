package com.trashclassifier.ck65; // <-- MUST match your package name

import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.example.vo_test";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            if (call.method.equals("getData")) {
                                String response = getDataFromSQLServer();
                                result.success(response);
                            } else {
                                result.notImplemented();
                            }
                        }
                );
    }

    private String getDataFromSQLServer() {
        String response = "";
        Connection conn = null;
        Statement stmt = null;

        try {
            Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");

            // Replace with your actual SQL Server connection string
            String url = "jdbc:sqlserver://192.168.0.100:1433;databaseName=YourDB;user=sa;password=yourpassword;encrypt=false;";
            conn = DriverManager.getConnection(url);
            stmt = conn.createStatement();

            ResultSet rs = stmt.executeQuery("SELECT TOP 1 name FROM your_table");

            if (rs.next()) {
                response = rs.getString("name");
            }

            rs.close();
            stmt.close();
            conn.close();
        } catch (Exception e) {
            response = "Error: " + e.getMessage();
        }

        return response;
    }
}
