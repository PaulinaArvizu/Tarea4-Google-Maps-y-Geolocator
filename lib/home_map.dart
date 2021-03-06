import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoder/geocoder.dart';

class HomeMap extends StatefulWidget {
  const HomeMap({Key key}) : super(key: key);

  @override
  _HomeMapState createState() => _HomeMapState();
}

class _HomeMapState extends State<HomeMap> {
  Set<Marker> _mapMarkers = Set();
  Set<Polygon> _mapPolygons = Set<Polygon>();
  bool _showMapPolygons = false;
  GoogleMapController _mapController;
  Position _currentPosition;
  Position _defaultPosition = Position(
    longitude: 20.608148,
    latitude: -103.417576,
  ); //ubicacion iteso
  TextEditingController _addressController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _getCurrentPosition(),
      builder: (context, result) {
        if (result.error == null) {
          if (_currentPosition == null) _currentPosition = _defaultPosition;
          return Scaffold(
            body: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      _currentPosition.latitude,
                      _currentPosition.longitude,
                    ),
                  ),
                  onMapCreated: _onMapCreated,
                  markers: _mapMarkers,
                  onLongPress: _setMarker,
                  polygons: _mapPolygons,
                ),
                Positioned(
                  top: 40,
                  left: 20,
                  right: 20,
                  child: Container(
                    color: Colors.white,
                    child: TextFormField(
                      controller: _addressController,
                      onFieldSubmitted: (value) async {
                        var place = await _getAddress(value);
                        showModalBottomSheet(
                          context: context,
                          builder: (builder) {
                            return Container(
                              height:
                                  50, //MediaQuery.of(context).size.height / 8,
                              child: Center(
                                child: Text(place),
                              ),
                            );
                          },
                        );
                      },
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search address',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            floatingActionButton: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  onPressed: () {
                    _showMapPolygons = !_showMapPolygons;
                    _createPolygons();
                  },
                  child: Icon(Icons.linear_scale),
                ),
                SizedBox(height: 10),
                FloatingActionButton(
                  onPressed: _moveToCurrentPosition,
                  child: Icon(Icons.my_location),
                ),
              ],
            ),
            // floatingActionButton: FloatingActionButton(
            //   onPressed: () {
            //     Share.share("$_currentPosition", subject: "Aqui me encuentro");
            //   },
            //   child: Icon(Icons.share),
            // ),
          );
        } else {
          Scaffold(
            body: Center(
              child: Text("Se ha producido un error"),
            ),
          );
        }
        return Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  void _onMapCreated(controller) {
    setState(() {
      _mapController = controller;
    });
  }

  void _setMarker(LatLng coord) async {
    // get address
    String _markerAddress = await _getGeocodingAddress(
      Position(
        latitude: coord.latitude,
        longitude: coord.longitude,
      ),
    );

    // add marker
    setState(() {
      _mapMarkers.add(
        Marker(
          markerId: MarkerId(coord.toString()),
          position: coord,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          // infoWindow: InfoWindow(
          //   title: coord.toString(),
          //   snippet: _markerAddress,
          // ),
          onTap: () {
            showModalBottomSheet(
              context: context,
              builder: (builder) {
                return Container(
                  height: MediaQuery.of(context).size.height / 8,
                  child: Center(
                      child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(coord.toString()),
                      Text(_markerAddress),
                    ],
                  )),
                );
              },
            );
          },
        ),
      );
    });
  }

  Future<void> _getCurrentPosition() async {
    // verify permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    // get current position
    _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    // get address
    String _currentAddress = await _getGeocodingAddress(_currentPosition);

    // add marker
    _mapMarkers.add(
      Marker(
        markerId: MarkerId(_currentPosition.toString()),
        position: LatLng(_currentPosition.latitude, _currentPosition.longitude),
        infoWindow: InfoWindow(
          title: _currentPosition.toString(),
          snippet: _currentAddress,
        ),
      ),
    );

    // move camera
    _mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            _currentPosition.latitude,
            _currentPosition.longitude,
          ),
          zoom: 15.0,
        ),
      ),
    );
  }

  Future<void> _moveToCurrentPosition() async {
    _mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            _currentPosition.latitude,
            _currentPosition.longitude,
          ),
          zoom: 18.0,
        ),
      ),
    );
  }

  Future<String> _getGeocodingAddress(Position position) async {
    // geocoding
    var places = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (places != null && places.isNotEmpty) {
      final Placemark place = places.first;
      return "${place.thoroughfare}, ${place.locality}";
    }
    return "No address available";
  }

  void _createPolygons() {
    List<LatLng> polygonPointsList = List<LatLng>();
    _mapPolygons = Set();
    if (!_showMapPolygons) {
      setState(() {});
      return;
    }
    for (int i = 0; i < _mapMarkers.length; i++)
      polygonPointsList.add(_mapMarkers.elementAt(i).position);
    _mapPolygons.add(
      new Polygon(
        polygonId: PolygonId('marker'),
        points: polygonPointsList,
        strokeColor: Colors.blue,
        strokeWidth: 1,
        fillColor: Colors.blue[100].withOpacity(0.5),
      ),
    );
    setState(() {});
  }

  Future<String> _getAddress(String address) async {
    // geocoding
    try {
      List<Address> addresses =
          await Geocoder.local.findAddressesFromQuery(address);
      var first = addresses.first;
      String addressLine = first.addressLine;

      // move camera
      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              first.coordinates.latitude,
              first.coordinates.longitude,
            ),
            zoom: 10,
          ),
        ),
      );
      return addressLine;
    } catch (e) {
      print(e);
      return 'No address found.';
    }
  }
}
