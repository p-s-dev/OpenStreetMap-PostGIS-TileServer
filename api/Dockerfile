FROM node:20-alpine

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# Copy package files
COPY package.json ./

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source code
COPY tsconfig.json ./
COPY src ./src

# Build TypeScript
RUN pnpm run build

# Remove dev dependencies
RUN pnpm prune --prod

# Expose port
EXPOSE 8080

# Run the application
CMD ["node", "dist/server.js"]
