const NextAuth = jest.fn().mockReturnValue({
  GET: jest.fn(),
  POST: jest.fn(),
});

export default NextAuth; 