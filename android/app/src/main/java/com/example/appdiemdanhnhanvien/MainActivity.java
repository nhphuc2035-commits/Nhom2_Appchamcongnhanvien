package com.example.appdiemdanhnhanvien;

import android.os.Build;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyPermanentlyInvalidatedException;
import android.security.keystore.KeyProperties;
import androidx.annotation.NonNull;
import androidx.biometric.BiometricManager;
import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import java.security.KeyStore;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;

public class MainActivity extends FlutterFragmentActivity {
    private static final String CHANNEL = "com.example.appdiemdanhnhanvien/biometric_security";
    private static final String KEY_ALIAS = "nova_biometric_detector_key_v1";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler((call, result) -> {
                switch (call.method) {
                    case "initDetectorKey":
                        try {
                            generateKey();
                            result.success(true);
                        } catch (Exception e) {
                            result.error("INIT_ERROR", e.getMessage(), null);
                        }
                        break;
                    case "checkBiometricChanged":
                        result.success(checkKeyInvalidated());
                        break;
                    case "resetDetectorKey":
                        try {
                            deleteKey();
                            generateKey();
                            result.success(true);
                        } catch (Exception e) {
                            result.error("RESET_ERROR", e.getMessage(), null);
                        }
                        break;
                    default:
                        result.notImplemented();
                        break;
                }
            });
    }

    private void generateKey() throws Exception {
        KeyStore keyStore = KeyStore.getInstance("AndroidKeyStore");
        keyStore.load(null);
        if (keyStore.containsAlias(KEY_ALIAS)) {
            keyStore.deleteEntry(KEY_ALIAS);
        }

        KeyGenerator keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");

        KeyGenParameterSpec.Builder builder = new KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_CBC)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_PKCS7)
            .setUserAuthenticationRequired(true);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            builder.setInvalidatedByBiometricEnrollment(true);
        }

        keyGenerator.init(builder.build());
        keyGenerator.generateKey();
    }

    private void deleteKey() {
        try {
            KeyStore keyStore = KeyStore.getInstance("AndroidKeyStore");
            keyStore.load(null);
            if (keyStore.containsAlias(KEY_ALIAS)) {
                keyStore.deleteEntry(KEY_ALIAS);
            }
        } catch (Exception ignored) {}
    }

    private String checkKeyInvalidated() {
        try {
            // 1. Kiểm tra phần cứng và số lượng vân tay đã cài trên máy
            BiometricManager biometricManager = BiometricManager.from(this);
            int canAuth = biometricManager.canAuthenticate(
                BiometricManager.Authenticators.BIOMETRIC_STRONG | BiometricManager.Authenticators.BIOMETRIC_WEAK);

            if (canAuth == BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE) {
                return "NO_HARDWARE";
            }
            if (canAuth == BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED) {
                return "NONE_ENROLLED";
            }
            if (canAuth == BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE) {
                return "HW_UNAVAILABLE";
            }

            // 2. Kiểm tra tính hợp lệ của Khóa Keystore (phát hiện thêm/xóa/sửa vân tay)
            KeyStore keyStore = KeyStore.getInstance("AndroidKeyStore");
            keyStore.load(null);

            if (!keyStore.containsAlias(KEY_ALIAS)) {
                generateKey();
                return "VALID";
            }

            SecretKey secretKey = (SecretKey) keyStore.getKey(KEY_ALIAS, null);
            if (secretKey == null) {
                generateKey();
                return "VALID";
            }

            Cipher cipher = Cipher.getInstance("AES/CBC/PKCS7Padding");
            cipher.init(Cipher.ENCRYPT_MODE, secretKey);
            return "VALID";
        } catch (KeyPermanentlyInvalidatedException e) {
            // Thực sự bị hủy do người dùng thêm/xóa vân tay trong Cài đặt Android
            return "CHANGED";
        } catch (Throwable e) {
            // Kiểm tra tên Exception phòng trường hợp nhà sản xuất OEM bọc trong Exception khác
            String exName = e.getClass().getName();
            String msg = e.getMessage() != null ? e.getMessage() : "";
            if (exName.contains("KeyPermanentlyInvalidatedException") ||
                msg.contains("Key permanently invalidated")) {
                return "CHANGED";
            }
            // UserNotAuthenticatedException hoặc các ngoại lệ khác khi chưa xác thực vân tay:
            // Khóa Keystore vẫn an toàn và hợp lệ hoàn toàn, không phải bị đổi vân tay
            return "VALID";
        }
    }
}
