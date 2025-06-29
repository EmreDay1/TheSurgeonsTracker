import React, { useState, useEffect } from 'react';
import { 
  View, 
  Text, 
  TouchableOpacity, 
  StyleSheet, 
  SafeAreaView,
  Alert
} from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { signOut, getCurrentUser } from '../services/auth';

export default function AuthSuccess() {
  const [user, setUser] = useState(null);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    loadUserData();
  }, []);

  const loadUserData = async () => {
    try {
      const currentUser = await getCurrentUser();
      setUser(currentUser);
      console.log('Current user loaded:', currentUser?.email);
    } catch (error) {
      console.error('Error loading user data:', error.message);
    }
  };

  const handleSignOut = async () => {
    Alert.alert(
      'Çıkış Yap',
      'Hesabınızdan çıkmak istediğinizden emin misiniz?',
      [
        {
          text: 'İptal',
          style: 'cancel',
        },
        {
          text: 'Çıkış Yap',
          style: 'destructive',
          onPress: performSignOut,
        },
      ]
    );
  };

  const performSignOut = async () => {
    try {
      setIsLoading(true);
      await signOut();
      console.log('User signed out successfully');
      // Navigation back to sign in will be handled by App.js auth state change
    } catch (error) {
      console.error('Sign out error:', error.message);
      Alert.alert(
        'Hata',
        'Çıkış yapılırken bir hata oluştu. Lütfen tekrar deneyin.',
        [{ text: 'Tamam' }]
      );
    } finally {
      setIsLoading(false);
    }
  };

  const getUserDisplayName = () => {
    if (user?.user_metadata?.first_name && user?.user_metadata?.last_name) {
      return `${user.user_metadata.first_name} ${user.user_metadata.last_name}`;
    }
    if (user?.user_metadata?.full_name) {
      return user.user_metadata.full_name;
    }
    if (user?.email) {
      return user.email.split('@')[0]; // Use email prefix as fallback
    }
    return 'Kullanıcı';
  };

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar style="light" backgroundColor="#1a365d" />
      
      <View style={styles.content}>
        {/* Header */}
        <View style={styles.header}>
          <View style={styles.logoContainer}>
            <View style={styles.pillIcon}>
              <Text style={styles.pillText}>💊</Text>
            </View>
          </View>
          <Text style={styles.appTitle}>PillTracker</Text>
          <Text style={styles.welcomeText}>Hoş Geldiniz!</Text>
        </View>

        {/* Success Content */}
        <View style={styles.successContainer}>
          <View style={styles.successIcon}>
            <Text style={styles.successEmoji}>🎉</Text>
          </View>
          
          <Text style={styles.successTitle}>Başarıyla Giriş Yaptınız!</Text>
          
          <Text style={styles.userName}>
            Merhaba, {getUserDisplayName()}
          </Text>
          
          <Text style={styles.successMessage}>
            PillTracker'a hoş geldiniz! İlaçlarınızı takip etmeye ve sağlığınızın kontrolünü elinize almaya hazırsınız.
          </Text>

          {user?.email && (
            <View style={styles.userInfoContainer}>
              <Text style={styles.userInfoLabel}>E-posta:</Text>
              <Text style={styles.userInfoValue}>{user.email}</Text>
            </View>
          )}

          {/* Action Buttons */}
          <View style={styles.buttonContainer}>
            <TouchableOpacity 
              style={styles.continueButton}
              onPress={() => console.log('Navigate to main dashboard')}
              disabled={isLoading}
            >
              <Text style={styles.continueButtonText}>
                Uygulamaya Devam Et
              </Text>
            </TouchableOpacity>

            <TouchableOpacity 
              style={styles.signOutButton}
              onPress={handleSignOut}
              disabled={isLoading}
            >
              <Text style={styles.signOutButtonText}>
                {isLoading ? 'Çıkış Yapılıyor...' : 'Çıkış Yap'}
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#1a365d',
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    paddingHorizontal: '8%',
  },
  header: {
    alignItems: 'center',
    marginBottom: '10%',
  },
  logoContainer: {
    marginBottom: '4%',
  },
  pillIcon: {
    width: 80,
    height: 80,
    backgroundColor: 'white',
    borderRadius: 40,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  pillText: {
    fontSize: 40,
  },
  appTitle: {
    fontSize: 32,
    fontWeight: 'bold',
    color: 'white',
    marginBottom: 8,
  },
  welcomeText: {
    fontSize: 18,
    color: '#cbd5e0',
    textAlign: 'center',
  },
  successContainer: {
    backgroundColor: 'white',
    borderRadius: 30,
    paddingHorizontal: '8%',
    paddingVertical: '10%',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 10,
    },
    shadowOpacity: 0.3,
    shadowRadius: 25,
    elevation: 25,
  },
  successIcon: {
    marginBottom: 20,
  },
  successEmoji: {
    fontSize: 60,
  },
  successTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1a365d',
    textAlign: 'center',
    marginBottom: 12,
  },
  userName: {
    fontSize: 20,
    fontWeight: '600',
    color: '#059669',
    textAlign: 'center',
    marginBottom: 16,
  },
  successMessage: {
    fontSize: 16,
    color: '#6b7280',
    textAlign: 'center',
    lineHeight: 24,
    marginBottom: 24,
  },
  userInfoContainer: {
    backgroundColor: '#f9fafb',
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 12,
    marginBottom: 32,
    width: '100%',
    borderWidth: 1,
    borderColor: '#e5e7eb',
  },
  userInfoLabel: {
    fontSize: 14,
    color: '#6b7280',
    marginBottom: 4,
  },
  userInfoValue: {
    fontSize: 16,
    color: '#111827',
    fontWeight: '500',
  },
  buttonContainer: {
    width: '100%',
    gap: 12,
  },
  continueButton: {
    backgroundColor: '#1a365d',
    borderRadius: 12,
    paddingVertical: 16,
    alignItems: 'center',
    shadowColor: '#1a365d',
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  continueButtonText: {
    color: 'white',
    fontSize: 18,
    fontWeight: 'bold',
  },
  signOutButton: {
    backgroundColor: 'transparent',
    borderWidth: 2,
    borderColor: '#ef4444',
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
  },
  signOutButtonText: {
    color: '#ef4444',
    fontSize: 16,
    fontWeight: '600',
  },
});
