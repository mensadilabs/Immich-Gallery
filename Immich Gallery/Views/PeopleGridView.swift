//
//  PeopleGridView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct PeopleGridView: View {
    @ObservedObject var peopleService: PeopleService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var assetService: AssetService
    @State private var people: [Person] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedPerson: Person?
    @State private var showingPersonPhotos = false
    @FocusState private var focusedPersonId: String?
    
    private let columns = [
        GridItem(.fixed(300), spacing: 100),
        GridItem(.fixed(300), spacing: 100),
        GridItem(.fixed(300), spacing: 100),
        GridItem(.fixed(300), spacing: 100),
    ]
    
    var body: some View {
        ZStack {
            // Background
            SharedGradientBackground()
            
            if isLoading {
                ProgressView("Loading people...")
                    .foregroundColor(.white)
                    .scaleEffect(1.5)
            } else if let errorMessage = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    Text("Error")
                        .font(.title)
                        .foregroundColor(.white)
                    Text(errorMessage)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") {
                        loadPeople()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if people.isEmpty {
                VStack {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No People Found")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("People detected in your photos will appear here")
                        .foregroundColor(.gray)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 50) {
                        ForEach(people) { person in
                            Button(action: {
                                print("Person selected: \(person.id)")
                                selectedPerson = person
                                showingPersonPhotos = true
                            }) {
                                PersonThumbnailView(
                                    person: person,
                                    peopleService: peopleService,
                                    assetService: assetService,
                                    isFocused: focusedPersonId == person.id
                                ).padding(20)
                            }
                            .frame(width: 300, height: 360)
                            .focused($focusedPersonId, equals: person.id)
                            .animation(.easeInOut(duration: 0.2), value: focusedPersonId)
                            .buttonStyle(CardButtonStyle())
                        }
                        .padding(50)
                        
                    }
                    
                }
            }
        }
        .fullScreenCover(isPresented: $showingPersonPhotos) {
            if let selectedPerson = selectedPerson {
                PersonPhotosView(person: selectedPerson, peopleService: peopleService, authService: authService, assetService: assetService)
            }
        }
        .onAppear {
            print("PeopleGridView: View appeared, people count: \(people.count), isLoading: \(isLoading), errorMessage: \(errorMessage ?? "nil")")
            if people.isEmpty {
                loadPeople()
            }
        }
    }
    
    private func loadPeople() {
        print("PeopleGridView: loadPeople called - isAuthenticated: \(authService.isAuthenticated)")
        guard authService.isAuthenticated else {
            errorMessage = "Not authenticated. Please check your credentials."
            return
        }
        
        print("Loading people - isAuthenticated: \(authService.isAuthenticated), baseURL: \(authService.baseURL)")
        
        isLoading = true
        errorMessage = nil
        print("PeopleGridView: Set loading state to true")
        
        Task {
            do {
                let fetchedPeople = try await peopleService.getAllPeople()
                print("Successfully fetched \(fetchedPeople.count) people")
                await MainActor.run {
                    self.people = fetchedPeople
                    self.isLoading = false
                    print("PeopleGridView: Updated UI with \(self.people.count) people, isLoading: \(self.isLoading)")
                }
            } catch {
                print("Error fetching people: \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    print("PeopleGridView: Set error state, isLoading: \(self.isLoading)")
                }
            }
        }
    }
}

struct PersonThumbnailView: View {
    let person: Person
    @ObservedObject var peopleService: PeopleService
    @ObservedObject var assetService: AssetService
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var thumbnails: [UIImage] = []
    @State private var currentThumbnailIndex = 0
    @State private var animationTimer: Timer?
    @State private var isLoadingThumbnails = false
    @State private var enableThumbnailAnimation: Bool = UserDefaults.standard.enableThumbnailAnimation
    let isFocused: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 300, height: 300)
                
                if isLoadingThumbnails {
                    ProgressView()
                        .scaleEffect(1.2)
                        .foregroundColor(.white)
                } else if !thumbnails.isEmpty {
                    // Animated thumbnails
                    ZStack {
                        ForEach(Array(thumbnails.enumerated()), id: \.offset) { index, thumbnail in
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 300, height: 300)
                                .clipped()
                                .cornerRadius(12)
                                .opacity(index == currentThumbnailIndex ? 1.0 : 0.0)
                                .animation(.easeInOut(duration: 1.5), value: currentThumbnailIndex)
                        }
                    }
                } else if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else if let image = image {
                    // Fallback to single person image
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 300, height: 300)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    // Fallback to icon
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
            }
            
            // Person info
            VStack(alignment: .leading, spacing: 4) {
                HStack{
                    Text(person.name.isEmpty ? "Unknown Person" : person.name)
                        .font(.headline)
                        .foregroundColor(isFocused ? .white : .gray)
                        .lineLimit(1)
                    Spacer()
                    if let isFavorite = person.isFavorite, isFavorite {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                if let birthDate = person.birthDate {
                    Text("Born: \(formatDate(birthDate))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: 300, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .frame(width: 300)
        .onAppear {
            loadPersonThumbnail()
            loadPersonThumbnails()
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: isFocused) { focused in
            if focused {
                stopAnimation()
            } else if !thumbnails.isEmpty && thumbnails.count > 1 && enableThumbnailAnimation {
                startAnimation()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            let newSetting = UserDefaults.standard.enableThumbnailAnimation
            if newSetting != enableThumbnailAnimation {
                enableThumbnailAnimation = newSetting
                if enableThumbnailAnimation && !thumbnails.isEmpty && thumbnails.count > 1 && !isFocused {
                    startAnimation()
                } else {
                    stopAnimation()
                }
            }
        }
    }
    
    private func loadPersonThumbnail() {
        Task {
            do {
                let thumbnail = try await thumbnailCache.getThumbnail(for: person.id, size: "thumbnail") {
                    // Load from server if not in cache
                    try await peopleService.loadPersonThumbnail(personId: person.id)
                }
                await MainActor.run {
                    self.image = thumbnail
                    self.isLoading = false
                }
            } catch {
                print("Failed to load person thumbnail for person \(person.id): \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
    
    private func loadPersonThumbnails() {
        guard !isLoadingThumbnails else { return }
        isLoadingThumbnails = true
        
        Task {
            do {
                let searchResult = try await assetService.fetchAssets(page: 1, limit: 10, personId: person.id)
                let imageAssets = searchResult.assets.filter { $0.type == .image }
                
                var loadedThumbnails: [UIImage] = []
                
                for asset in imageAssets.prefix(10) {
                    do {
                        let thumbnail = try await thumbnailCache.getThumbnail(for: asset.id, size: "thumbnail") {
                            try await assetService.loadImage(asset: asset, size: "thumbnail")
                        }
                        if let thumbnail = thumbnail {
                            loadedThumbnails.append(thumbnail)
                        }
                    } catch {
                        print("Failed to load thumbnail for asset \(asset.id): \(error)")
                    }
                }
                
                await MainActor.run {
                    self.thumbnails = loadedThumbnails
                    self.isLoadingThumbnails = false
                    if !loadedThumbnails.isEmpty && enableThumbnailAnimation {
                        self.startAnimation()
                    }
                }
            } catch {
                print("Failed to fetch assets for person \(person.id): \(error)")
                await MainActor.run {
                    self.isLoadingThumbnails = false
                }
            }
        }
    }
    
    private func startAnimation() {
        guard thumbnails.count > 1 && enableThumbnailAnimation else { return }
        stopAnimation()
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1.5)) {
                currentThumbnailIndex = (currentThumbnailIndex + 1) % thumbnails.count
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

struct PersonPhotosView: View {
    let person: Person
    @ObservedObject var peopleService: PeopleService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var assetService: AssetService
    @Environment(\.dismiss) private var dismiss
    @State private var showingSlideshow = false
    @State private var personAssets: [ImmichAsset] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                AssetGridView(
                    assetService: assetService,
                    authService: authService,
                    albumId: nil,
                    personId: person.id,
                    tagId: nil,
                    onAssetsLoaded: { loadedAssets in
                        self.personAssets = loadedAssets
                    }
                )
            }
            .navigationTitle(person.name.isEmpty ? "Unknown Person" : person.name)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: startSlideshow) {
                        Image(systemName: "play.rectangle")
                            .foregroundColor(.white)
                    }
                    .disabled(personAssets.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            })
        }
        .fullScreenCover(isPresented: $showingSlideshow) {
            let imageAssets = personAssets.filter { $0.type == .image }
            if !imageAssets.isEmpty {
                SlideshowView(assets: imageAssets, assetService: assetService, startingIndex: 0)
            }
        }
    }
    
    private func startSlideshow() {
        let imageAssets = personAssets.filter { $0.type == .image }
        if !imageAssets.isEmpty {
            showingSlideshow = true
        }
    }
}

#Preview {
    let (_, authService, assetService, _, peopleService, _) =
         MockServiceFactory.createMockServices()
    PeopleGridView(peopleService: peopleService, authService: authService, assetService: assetService)
}
