var app = angular.module('urlchecker', ['ngGrid']);

app.controller('URLController', function($scope, $http) {
  $http.get('/results').success(function(data) {
  $scope.urls = data;
  $scope.set_color = function(response) {
    if (response > 200 ) {
      return { float: 'left', width: '45px', color: "white", background: "red" }
    } else {
      return { float: 'left', width: '45px', color: "white", background: "green" }
    };
  };
  });
});
