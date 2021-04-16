export default {
  async httpRequest(url, options = {}) {
    const response = await fetch(
      url,
      Object.assign(
        {
          mode: 'cors',
          headers: {
            'Content-Type': 'application/json'
          }
        },
        options
      )
    );

    return response.json();
  }
};
