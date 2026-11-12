import { StatusBar, StyleSheet, Text, View } from 'react-native';

function App() {
  return (
    <View style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#f4f6f8" />
      <Text style={styles.title}>Bonjour Android v6 !</Text>
      <Text style={styles.subtitle}>Votre application React Native fonctionne.</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
    backgroundColor: '#f4f6f8',
  },
  title: {
    color: '#17202a',
    fontSize: 28,
    fontWeight: '700',
  },
  subtitle: {
    marginTop: 12,
    color: '#52616b',
    fontSize: 16,
    textAlign: 'center',
  },
});

export default App;
