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
        GridItem(.fixed(300), spacing: 50),
        GridItem(.fixed(300), spacing: 50),
        GridItem(.fixed(300), spacing: 50),
        GridItem(.fixed(300), spacing: 50),
        GridItem(.fixed(300), spacing: 50),
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
                            UIKitFocusable(action: {
                                print("Person selected: \(person.id)")
                                selectedPerson = person
                                showingPersonPhotos = true
                            }) {
                                PersonThumbnailView(
                                    person: person,
                                    peopleService: peopleService,
                                    isFocused: focusedPersonId == person.id
                                )
                            }
                            .frame(width: 300, height: 360)
                            .focused($focusedPersonId, equals: person.id)
                            .scaleEffect(focusedPersonId == person.id ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: focusedPersonId)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
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
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    @State private var image: UIImage?
    @State private var isLoading = true
    let isFocused: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 300, height: 300)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 300, height: 300)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
            }
            .shadow(color: .black.opacity(isFocused ? 0.5 : 0), radius: 15, y: 10)
            
            // Person info
            VStack(alignment: .leading, spacing: 4) {
                Text(person.name.isEmpty ? "Unknown Person" : person.name)
                    .font(.headline)
                    .foregroundColor(isFocused ? .white : .gray)
                    .lineLimit(1)
                
                if let birthDate = person.birthDate {
                    Text("Born: \(formatDate(birthDate))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Text("Tap to view photos")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if let isFavorite = person.isFavorite, isFavorite {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("Favorite")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .frame(maxWidth: 300, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .frame(width: 300)
        .onAppear {
            loadPersonThumbnail()
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
            .toolbar {
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
            }
        }
        .fullScreenCover(isPresented: $showingSlideshow) {
            let imageAssets = personAssets.filter { $0.type == .image }
            if !imageAssets.isEmpty {
                SlideshowView(assets: imageAssets, assetService: assetService)
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
    let networkService = NetworkService()
    let peopleService = PeopleService(networkService: networkService)
    let authService = AuthenticationService(networkService: networkService)
    let assetService = AssetService(networkService: networkService)
    PeopleGridView(peopleService: peopleService, authService: authService, assetService: assetService)
} 