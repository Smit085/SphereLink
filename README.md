
---

# 🌐 SphereLink

**Immerse yourself in interactive 360° virtual tours.**  
SphereLink is a Flutter-based mobile application that transforms static panoramic images into dynamic, interactive experiences. Create, customize, and explore virtual tours with markers, multimedia, and seamless navigation, perfect for real estate, tourism, education, and more.

---

## 🚀 Features

- **Immersive 360° Tours**: Explore panoramic views with smooth panning, tilting, and zooming.  
- **Interactive Markers**: Add customizable markers with icons, labels, links, and multimedia content.  
- **Real-Time Collaboration**: Future-ready for multi-user editing and live updates.  
- **AR & IoT Integration**: Supports augmented reality markers and IoT device connectivity.  
- **User-Friendly UI**: Intuitive interface for creating, browsing, and publishing tours.  
- **Cross-Platform**: Built with Flutter for Android and iOS compatibility.  
- **Scalable Design**: Modular architecture for easy feature expansion.

---

## 🖥️ Tech Stack

- **Frontend**: Flutter (Dart) and Google Fonts.
- **Backend**: Java and PostgreSQL.
- **APIs**: Google API, Mappls APIs for map services.
- **Tools**: Android Studio, Spring Boot, Postman, PgAdmin and Git.

---

## 📸 Screenshots  

| Feature          | Screenshot                                                                                            |  
|------------------|-------------------------------------------------------------------------------------------------------|  
| Home Screen      | ![image](https://github.com/user-attachments/assets/07cdc5d3-b2cb-4c46-96d7-400356909940)             |  
| Virtual Tour     | ![image](https://github.com/user-attachments/assets/ba2e5041-6cc6-43c7-920c-9e6acc165e1b)             |  
| Tour on Map      | ![View Location](https://github.com/user-attachments/assets/82ca3e74-b489-4a64-9bef-b1ef2dff69a9)     |  

---

## 📂 Project Structure  

```
📂 SphereLink
├── 📁 android
    ├── 📁 app            # Android-specific configurations
├── 📁 lib                # Flutter project files
    ├── 📁 core           # App configurations and session utilities
    ├── 📁 data           # App data models.
    ├── 📁 screens        # UI screens (HomeScreen, ExploreScreen, etc.)
    ├── 📁 utils          # Custom utilities (colors, widgets)
    ├── 📁 widgets        # Reusable UI components
├── 📁 assets             # Images, fonts, and other resources
├── 📄 README.md          # Project documentation
```

## 🛠️ Setup Instructions  

### Prerequisites
- Install [Flutter](https://flutter.dev/) and [Android Studio](https://developer.android.com/studio).  
- Ensure dependencies (panorama_viewer, geolocator, cached_network_image, etc.) are added to pubspec.yaml.
- Setup the [backend](https://github.com/Smit085/SphereLink-Backend) with Spring Boot and PgAdmin.
- Optional: VR headset for testing.

### Steps
1. **Clone the Repository**:  
   ```bash
   git clone https://github.com/Smit085/SphereLink.git  
   cd SphereLink  
   ```
   
2. **Setup Flutter App**:  
   ```bash  
   flutter pub get  
   flutter run  
   ```

3. **Configure APIs**:  
   ```bash  
   flutter pub get  
   flutter run  
   ```  
   Add Mappls SDK and Google Cloud API keys to lib/core/AppConfig.dart.

3. **Run the App**:
   ```bash
   flutter run
   ```
---

## 🎯 Roadmap

- [ ] Cloud storage for tour synchronization across devices.  
- [ ] Real-time multi-user collaboration for co-editing tours.  
- [ ] Advanced marker interactions.
- [ ] Social sharing and community features.  
- [ ] In-app tutorials for new users.  
- [ ] Performance optimization for low-end devices.

---

## 🤝 Contributing  

Contributions are welcome! Please fork the repository, create a feature branch, and submit a pull request.  

---

## 💬 Feedback  

For feature requests or bug reports, open an issue [here](https://github.com/Smit085/SphereLink/issues).

---

> **Crafted with ❤️ by [SAP](https://github.com/Smit085)**

--- 
